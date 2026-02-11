package handlers

import (
	"context"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/config"
	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
)

type startMomentRequest struct {
	Prompt string `json:"prompt" binding:"required"`
}

type startMomentResponse struct {
	SessionID string `json:"session_id"`
	CoachName string `json:"coach_name"` // Generic name until coach is selected
}

// StartMoment handles POST /v1/moments/start
// This endpoint:
// 1. Creates session immediately without coach selection
// 2. Saves user's initial message
// 3. Returns session ID for immediate navigation
// 4. Coach selection happens during streaming
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

		// Create session immediately without coach selection
		// Coach will be determined during streaming
		session := models.Session{
			UID:       uid,
			CoachID:   nil, // Will be set during streaming
			Title:     "New Moment",
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

		// Increment moment count if not Pro
		if !isPro {
			if err := incrementMomentCount(ctx, fs, uid); err != nil {
				// Log error but don't fail the request
				c.Error(err)
			}
		}

		// Return session immediately for navigation
		// Client will start streaming to get the response
		response := startMomentResponse{
			SessionID: sessionID,
			CoachName: "AI Coach", // Generic name until coach is selected
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
