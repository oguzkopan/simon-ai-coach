package handlers

import (
	"context"
	"fmt"
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
	"simon-backend/internal/orchestrator"
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

// StreamChat streams chat responses using SSE with multi-agent orchestration
func StreamChat(fs *fsClient.Client, gm *geminiClient.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		log.Printf("StreamChat: uid=%s, sessionID=%s", uid, sessionID)

		// Parse request body
		var req struct {
			Message string `json:"message" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

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
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "SESSION_NOT_FOUND",
				"message": "session not found",
			})
			flusher.Flush()
			return
		}

		var session models.Session
		if err := sessionDoc.DataTo(&session); err != nil {
			log.Printf("Error parsing session: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "SESSION_PARSE_ERROR",
				"message": "failed to parse session",
			})
			flusher.Flush()
			return
		}

		if session.UID != uid {
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "ACCESS_DENIED",
				"message": "access denied",
			})
			flusher.Flush()
			return
		}

		// Get coach ID
		coachID := ""
		if session.CoachID != nil {
			coachID = *session.CoachID
		}

		// Create pipeline
		pipeline := orchestrator.NewPipeline(fs, gm)

		// Execute pipeline
		output, err := pipeline.Execute(ctx, orchestrator.PipelineInput{
			SessionID:   sessionID,
			CoachID:     coachID,
			UserMessage: req.Message,
			UID:         uid,
		})
		if err != nil {
			log.Printf("Pipeline execution error: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "PIPELINE_ERROR",
				"message": fmt.Sprintf("Pipeline failed: %v", err),
			})
			flusher.Flush()
			return
		}

		// Keep-alive ticker (every 15 seconds)
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()

		// Connection timeout (5 minutes)
		timeout := time.NewTimer(5 * time.Minute)
		defer timeout.Stop()

		// Event ID counter
		eventID := 0

		// Stream events from pipeline
		for {
			select {
			case event, ok := <-output.Stream:
				if !ok {
					// Stream closed normally
					log.Printf("Stream closed: sessionID=%s", sessionID)
					return
				}

				// Increment event ID
				eventID++

				// Debug log the event
				log.Printf("SSE Event #%d: type=%s, data=%+v", eventID, event.Type, event.Data)

				// Write SSE event with ID
				if err := sse.EventWithID(c.Writer, fmt.Sprintf("%d", eventID), event.Type, event.Data); err != nil {
					log.Printf("Error writing SSE event: %v", err)
					return
				}
				flusher.Flush()
				log.Printf("Flushed event #%d to client", eventID)

				// Exit on completion or error
				if event.Type == "stream.done" || event.Type == "error" {
					log.Printf("Stream completed: sessionID=%s, type=%s", sessionID, event.Type)
					return
				}

			case <-ticker.C:
				// Send keep-alive comment
				if err := sse.KeepAlive(c.Writer); err != nil {
					log.Printf("Error sending keep-alive: %v", err)
					return
				}
				flusher.Flush()

			case <-timeout.C:
				// Connection timeout
				log.Printf("Connection timeout: sessionID=%s", sessionID)
				sse.Event(c.Writer, "error", map[string]interface{}{
					"code":    "TIMEOUT",
					"message": "Connection timeout after 5 minutes",
				})
				flusher.Flush()
				return

			case <-ctx.Done():
				// Client disconnected
				log.Printf("Client disconnected: sessionID=%s", sessionID)
				return
			}
		}
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

