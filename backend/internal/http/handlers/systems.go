package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
)

// ListSystems returns all pinned systems for the authenticated user
func ListSystems(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		_ = middleware.GetUID(c) // TODO: Use for filtering user systems

		// TODO: Implement systems repository
		// Query Firestore for systems where uid == authenticated user
		// For now, return empty array
		systems := []models.System{}

		c.JSON(http.StatusOK, systems)
	}
}

// CreateSystem creates a new pinned system
func CreateSystem(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		_ = middleware.GetUID(c) // TODO: Use for ownership

		var req models.System
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Validate required fields
		if req.Title == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "title is required"})
			return
		}

		if len(req.Checklist) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "checklist is required"})
			return
		}

		// Create system
		system := models.System{
			ID:                 uuid.New().String(),
			UID:                "", // TODO: Set from uid
			Title:              req.Title,
			Checklist:          req.Checklist,
			ScheduleSuggestion: req.ScheduleSuggestion,
			Metrics:            req.Metrics,
			SourceSessionID:    req.SourceSessionID,
			CreatedAt:          time.Now(),
		}

		// TODO: Save to Firestore
		// For now, just return the created system

		c.JSON(http.StatusCreated, system)
	}
}

// GetSystem returns a specific system by ID
func GetSystem(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		_ = middleware.GetUID(c) // TODO: Use for access control
		systemID := c.Param("id")

		if systemID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "system id is required"})
			return
		}

		// TODO: Fetch from Firestore and verify ownership
		// For now, return 404
		c.JSON(http.StatusNotFound, gin.H{"error": "system not found"})
	}
}

// DeleteSystem deletes a system by ID
func DeleteSystem(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		_ = middleware.GetUID(c) // TODO: Use for ownership check
		systemID := c.Param("id")

		if systemID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "system id is required"})
			return
		}

		// TODO: Delete from Firestore after verifying ownership
		// For now, return success

		c.JSON(http.StatusOK, gin.H{"message": "system deleted"})
	}
}
