package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
)

// GetContext handles GET /v1/context
// Returns the user's context vault (values, goals, constraints, projects)
func GetContext(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		// Get user document
		user, err := fs.GetUser(ctx, uid)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
			return
		}

		// Return context vault
		c.JSON(http.StatusOK, user.ContextVault)
	}
}

// UpdateContext handles PUT /v1/context
// Updates the user's context vault
func UpdateContext(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var contextVault models.UserContext
		if err := c.ShouldBindJSON(&contextVault); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Update user's context vault
		if err := fs.UpdateUserContext(ctx, uid, contextVault); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update context"})
			return
		}

		c.JSON(http.StatusOK, contextVault)
	}
}

type updateContextPreferenceRequest struct {
	IncludeContext bool `json:"include_context"`
}

// UpdateContextPreference handles PUT /v1/context/preference
// Updates whether to include context in coaching
func UpdateContextPreference(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var req updateContextPreferenceRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Update preference
		if err := fs.UpdateUserPreference(ctx, uid, "include_context", req.IncludeContext); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update preference"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"include_context": req.IncludeContext})
	}
}
