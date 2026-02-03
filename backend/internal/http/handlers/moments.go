package handlers

import (
	"context"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/agent"
	"simon-backend/internal/config"
	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator"
)

type startMomentRequest struct {
	Prompt string `json:"prompt" binding:"required"`
}

type startMomentResponse struct {
	SessionID    string  `json:"session_id"`
	CoachID      *string `json:"coach_id"`
	CoachName    string  `json:"coach_name"`
	FirstMessage *string `json:"first_message"`
}

// StartMoment handles POST /v1/moments/start
// This endpoint:
// 1. Checks Pro status or free tier limit
// 2. Uses router agent to classify intent
// 3. Routes to existing coach or generates new one
// 4. Creates session
// 5. Returns session ID and first message
func StartMoment(fs *firestore.Client, gm *gemini.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var req startMomentRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Check Pro status or free tier limit
		// TODO: Implement RevenueCat validation (Week 3)
		isPro := false // Placeholder

		if !isPro {
			// Check free tier limit (3 moments per day)
			count, err := getMomentsCountToday(ctx, fs, uid)
			if err != nil {
				c.Error(fmt.Errorf("failed to check moment limit: %w", err))
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check moment limit"})
				return
			}

			if count >= cfg.FreeTierMomentsPerDay {
				c.JSON(http.StatusPaymentRequired, gin.H{"error": "free tier limit reached"})
				return
			}
		}

		// Use router agent to classify intent and determine coach
		router := agent.NewRouter(gm, fs)
		routeResult, err := router.Route(ctx, uid, req.Prompt)
		if err != nil {
			c.Error(fmt.Errorf("failed to route moment: %w", err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to route moment: %v", err)})
			return
		}

		// Create session
		session := models.Session{
			UID:       uid,
			CoachID:   routeResult.CoachID,
			Title:     routeResult.Title,
			Mode:      "quick",
			CreatedAt: models.Now(),
			UpdatedAt: models.Now(),
		}

		sessionID, err := fs.CreateSession(ctx, session)
		if err != nil {
			c.Error(fmt.Errorf("failed to create session: %w", err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to create session: %v", err)})
			return
		}

		// Save user's initial message
		userMessage := models.Message{
			Role:        "user",
			ContentText: req.Prompt,
			CreatedAt:   models.Now(),
		}

		if err := fs.AddMessage(ctx, sessionID, userMessage); err != nil {
			c.Error(fmt.Errorf("failed to save message: %w", err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to save message: %v", err)})
			return
		}

		// Generate initial AI response using the orchestrator pipeline
		// This ensures the user gets an immediate response when using quick templates
		pipeline := orchestrator.NewPipeline(fs, gm)
		
		// Get coachID as string (handle pointer)
		coachIDStr := ""
		if routeResult.CoachID != nil {
			coachIDStr = *routeResult.CoachID
		}
		
		// Execute pipeline to generate the first response
		output, err := pipeline.Execute(ctx, orchestrator.PipelineInput{
			SessionID:   sessionID,
			CoachID:     coachIDStr,
			UserMessage: req.Prompt,
			Attachments: nil,
			UID:         uid,
		})
		
		if err != nil {
			c.Error(fmt.Errorf("failed to generate initial response: %w", err))
			// Don't fail the request - session is created, user can retry in chat
			c.JSON(http.StatusOK, startMomentResponse{
				SessionID:    sessionID,
				CoachID:      routeResult.CoachID,
				CoachName:    routeResult.CoachName,
				FirstMessage: nil,
			})
			return
		}
		
		// Collect the AI response from the stream
		var assistantText string
		var assistantMessageID string
		
		// Drain the stream to get the complete response
		for event := range output.Stream {
			if event.Type == "message.delta" {
				if delta, ok := event.Data["delta"].(string); ok {
					assistantText += delta
				}
			} else if event.Type == "message.final" {
				if msgID, ok := event.Data["message_id"].(string); ok {
					assistantMessageID = msgID
				}
				if text, ok := event.Data["text"].(string); ok {
					assistantText = text
				}
			}
		}
		
		// Save the assistant's response to Firestore
		if assistantText != "" && assistantMessageID != "" {
			assistantMessage := models.Message{
				ID:          assistantMessageID,
				Role:        "assistant",
				ContentText: assistantText,
				CreatedAt:   models.Now(),
			}
			
			if err := fs.AddMessage(ctx, sessionID, assistantMessage); err != nil {
				c.Error(fmt.Errorf("failed to save assistant message: %w", err))
				// Don't fail - the response was generated, just not saved
			}
		}

		// Increment moment count if not Pro
		if !isPro {
			if err := incrementMomentCount(ctx, fs, uid); err != nil {
				// Log error but don't fail the request
				c.Error(err)
			}
		}

		// Return response with the first message
		response := startMomentResponse{
			SessionID:    sessionID,
			CoachID:      routeResult.CoachID,
			CoachName:    routeResult.CoachName,
			FirstMessage: &assistantText,
		}

		c.JSON(http.StatusOK, response)
	}
}

// getMomentsCountToday returns the number of moments started today by the user
func getMomentsCountToday(ctx context.Context, fs *firestore.Client, uid string) (int, error) {
	// TODO: Implement Firestore query to count sessions created today
	// For now, return 0 (will be implemented with Firestore repos)
	return 0, nil
}

// incrementMomentCount increments the moment count for today
func incrementMomentCount(ctx context.Context, fs *firestore.Client, uid string) error {
	// TODO: Implement Firestore increment
	// For now, no-op
	return nil
}
