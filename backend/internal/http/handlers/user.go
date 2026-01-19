package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
)

// GetMe handles GET /v1/me
// Returns the current user's profile
func GetMe(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		user, err := fs.GetUser(ctx, uid)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}

// UpdateMe handles PUT /v1/me
// Updates the current user's profile
func UpdateMe(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var updates map[string]interface{}
		if err := c.ShouldBindJSON(&updates); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Update user
		if err := fs.UpdateUser(ctx, uid, updates); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"success": true})
	}
}

// DeleteMe handles DELETE /v1/me
// Deletes all user data (coaches, sessions, systems, context)
func DeleteMe(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		// Delete all user data
		if err := fs.DeleteAllUserData(ctx, uid); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete user data"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"success": true})
	}
}
