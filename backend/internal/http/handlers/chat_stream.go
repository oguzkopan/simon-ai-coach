package handlers

import (
	"context"
	"log"
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"google.golang.org/genai"

	"simon-backend/internal/config"
	fsClient "simon-backend/internal/firestore"
	geminiClient "simon-backend/internal/gemini"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/sse"
)

// SendMessage sends a message and returns immediately (non-streaming)
func SendMessage(fs *fsClient.Client, gm *geminiClient.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		var req models.SendMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Validate session ownership
		sessionDoc, err := fs.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}

		var session models.Session
		if err := sessionDoc.DataTo(&session); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse session"})
			return
		}

		if session.UID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		// Save user message
		userMsg := models.Message{
			ID:          uuid.New().String(),
			Role:        "user",
			ContentText: req.UserText,
			Attachments: req.Attachments,
			CreatedAt:   time.Now(),
		}

		_, err = fs.DB.Collection("sessions").Doc(sessionID).
			Collection("messages").Doc(userMsg.ID).Set(ctx, userMsg)
		if err != nil {
			log.Printf("Error saving user message: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save message"})
			return
		}

		// Update session timestamp
		_, err = fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, []firestore.Update{
			{Path: "updated_at", Value: time.Now()},
		})
		if err != nil {
			log.Printf("Error updating session: %v", err)
		}

		c.JSON(http.StatusOK, userMsg)
	}
}

// StreamChat streams chat responses using SSE
func StreamChat(fs *fsClient.Client, gm *geminiClient.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		log.Printf("StreamChat: uid=%s, sessionID=%s", uid, sessionID)

		// Initialize SSE
		flusher, ok := sse.Init(c.Writer)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "streaming not supported"})
			return
		}

		// Validate session ownership
		sessionDoc, err := fs.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			log.Printf("Error getting session: %v", err)
			_ = sse.Data(c.Writer, models.ChatDelta{
				Kind:  "error",
				Error: "session not found",
			})
			flusher.Flush()
			return
		}

		var session models.Session
		if err := sessionDoc.DataTo(&session); err != nil {
			log.Printf("Error parsing session: %v", err)
			_ = sse.Data(c.Writer, models.ChatDelta{
				Kind:  "error",
				Error: "failed to parse session",
			})
			flusher.Flush()
			return
		}

		if session.UID != uid {
			_ = sse.Data(c.Writer, models.ChatDelta{
				Kind:  "error",
				Error: "access denied",
			})
			flusher.Flush()
			return
		}

		// Get coach blueprint
		var coachBlueprint map[string]interface{}
		if session.CoachID != nil && *session.CoachID != "" {
			coachDoc, err := fs.DB.Collection("coaches").Doc(*session.CoachID).Get(ctx)
			if err == nil {
				var coach models.Coach
				if err := coachDoc.DataTo(&coach); err == nil {
					coachBlueprint = coach.Blueprint
				}
			}
		}

		// Get conversation history
		history, err := getConversationHistory(ctx, fs, sessionID)
		if err != nil {
			log.Printf("Error getting history: %v", err)
			_ = sse.Data(c.Writer, models.ChatDelta{
				Kind:  "error",
				Error: "failed to get conversation history",
			})
			flusher.Flush()
			return
		}

		// Build system prompt
		systemPrompt := buildSystemPrompt(coachBlueprint)

		// Build full prompt with history
		fullPrompt := systemPrompt + "\n\n" + buildHistoryPrompt(history) + "\n\nUser: " + req.Message

		// Stream from Gemini
		tokenChan, errChan := gm.GenerateContentStream(ctx, fullPrompt)

		var fullText string

		for {
			select {
			case token, ok := <-tokenChan:
				if !ok {
					// Stream finished
					goto streamDone
				}
				fullText += token
				_ = sse.Data(c.Writer, models.ChatDelta{
					Kind: "token",
					Text: token,
				})
				flusher.Flush()

			case err := <-errChan:
				if err != nil {
					log.Printf("Stream error: %v", err)
					_ = sse.Data(c.Writer, models.ChatDelta{
						Kind:  "error",
						Error: err.Error(),
					})
					flusher.Flush()
					return
				}
			}
		}

	streamDone:
		// Save assistant message
		assistantMsg := models.Message{
			ID:          uuid.New().String(),
			Role:        "assistant",
			ContentText: fullText,
			CreatedAt:   time.Now(),
		}

		_, err = fs.DB.Collection("sessions").Doc(sessionID).
			Collection("messages").Doc(assistantMsg.ID).Set(ctx, assistantMsg)
		if err != nil {
			log.Printf("Error saving assistant message: %v", err)
		}

		// Update session timestamp
		_, err = fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, []firestore.Update{
			{Path: "updated_at", Value: time.Now()},
		})
		if err != nil {
			log.Printf("Error updating session: %v", err)
		}

		// Send final event
		_ = sse.Data(c.Writer, models.ChatDelta{
			Kind: "final",
		})
		flusher.Flush()

		log.Printf("StreamChat completed: sessionID=%s, tokens=%d", sessionID, len(fullText))
	}
}

// Helper functions

func getConversationHistory(ctx context.Context, fs *fsClient.Client, sessionID string) ([]models.Message, error) {
	iter := fs.DB.Collection("sessions").Doc(sessionID).
		Collection("messages").
		OrderBy("created_at", firestore.Asc).
		Documents(ctx)
	defer iter.Stop()

	var messages []models.Message
	for {
		doc, err := iter.Next()
		if err != nil {
			break
		}

		var msg models.Message
		if err := doc.DataTo(&msg); err != nil {
			continue
		}
		messages = append(messages, msg)
	}

	return messages, nil
}

func buildSystemPrompt(blueprint map[string]interface{}) string {
	// Default system prompt
	prompt := `You are a minimalist AI coach. Your style:
- Ask ONE clarifying question first
- Give 3-step answers by default
- Offer to create a system when useful
- Be calm, direct, and actionable

Never give medical, legal, or financial advice. Suggest professional help when appropriate.`

	// TODO: Customize based on blueprint (Week 2)
	_ = blueprint

	return prompt
}

func buildHistoryPrompt(history []models.Message) string {
	if len(history) == 0 {
		return ""
	}

	var prompt string
	for _, msg := range history {
		role := msg.Role
		if role == "assistant" {
			role = "Assistant"
		} else {
			role = "User"
		}
		prompt += fmt.Sprintf("%s: %s\n\n", role, msg.ContentText)
	}
	return prompt
}

func buildGeminiContents(systemPrompt string, history []models.Message) []*genai.Content {
	contents := []*genai.Content{
		{
			Role: "user",
			Parts: []*genai.Part{
				{Text: systemPrompt},
			},
		},
	}

	for _, msg := range history {
		role := msg.Role
		if role == "assistant" {
			role = "model"
		}

		contents = append(contents, &genai.Content{
			Role: role,
			Parts: []*genai.Part{
				{Text: msg.ContentText},
			},
		})
	}

	return contents
}

func extractToken(resp *genai.GenerateContentResponse) string {
	if len(resp.Candidates) > 0 &&
		resp.Candidates[0].Content != nil &&
		len(resp.Candidates[0].Content.Parts) > 0 {
		return resp.Candidates[0].Content.Parts[0].Text
	}
	return ""
}
