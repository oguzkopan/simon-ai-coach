package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
)

// GetContext handles GET /v1/context
// Returns the user's context vault and preferences
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

		// Return context vault AND preferences
		c.JSON(http.StatusOK, gin.H{
			"context_vault": user.ContextVault,
			"preferences":   user.Preferences,
		})
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

// GetMemory handles GET /v1/memory
// Returns the user's structured memory
func GetMemory(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		// Get user document
		user, err := fs.GetUser(ctx, uid)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
			return
		}

		// Return structured memory (or empty if not initialized)
		if user.Memory == nil {
			c.JSON(http.StatusOK, models.UserMemory{
				Values:      []models.MemoryItem{},
				Goals:       []models.Goal{},
				Constraints: []models.MemoryItem{},
				Projects:    []models.Project{},
				Insights:    []models.Insight{},
			})
			return
		}

		c.JSON(http.StatusOK, user.Memory)
	}
}

// UpdateMemory handles PUT /v1/memory
// Updates the user's structured memory
func UpdateMemory(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var memory models.UserMemory
		if err := c.ShouldBindJSON(&memory); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Update timestamp
		memory.UpdatedAt = models.Now()

		// Update user's structured memory
		updates := map[string]interface{}{
			"memory":     memory,
			"updated_at": models.Now(),
		}

		if err := fs.UpdateUser(ctx, uid, updates); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update memory"})
			return
		}

		c.JSON(http.StatusOK, memory)
	}
}

type addGoalRequest struct {
	Text     string `json:"text" binding:"required"`
	Priority string `json:"priority,omitempty"` // "high" | "medium" | "low"
}

// AddGoal handles POST /v1/memory/goals
// Adds a new goal to user's memory
func AddGoal(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()

		var req addGoalRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Create new goal
		now := models.Now()
		goal := models.Goal{
			ID:        generateMemoryID("goal"),
			Text:      req.Text,
			Status:    "active",
			Priority:  req.Priority,
			CreatedAt: now,
			UpdatedAt: now,
			Source:    "user_input",
		}

		// Get user to check if memory is initialized
		user, err := fs.GetUser(ctx, uid)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
			return
		}

		// Initialize memory if needed
		if user.Memory == nil {
			updates := map[string]interface{}{
				"memory": models.UserMemory{
					Values:      []models.MemoryItem{},
					Goals:       []models.Goal{goal},
					Constraints: []models.MemoryItem{},
					Projects:    []models.Project{},
					Insights:    []models.Insight{},
					UpdatedAt:   now,
				},
				"updated_at": now,
			}
			if err := fs.UpdateUser(ctx, uid, updates); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to add goal"})
				return
			}
		} else {
			// Append to existing goals
			updates := map[string]interface{}{
				"memory.goals":      append(user.Memory.Goals, goal),
				"memory.updated_at": now,
				"updated_at":        now,
			}
			if err := fs.UpdateUser(ctx, uid, updates); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to add goal"})
				return
			}
		}

		c.JSON(http.StatusOK, goal)
	}
}

type updateGoalStatusRequest struct {
	Status string `json:"status" binding:"required"` // "active" | "completed" | "paused"
}

// UpdateGoalStatus handles PUT /v1/memory/goals/:id/status
// Updates a goal's status
func UpdateGoalStatus(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		ctx := c.Request.Context()
		goalID := c.Param("id")

		var req updateGoalStatusRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Get user
		user, err := fs.GetUser(ctx, uid)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
			return
		}

		if user.Memory == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "goal not found"})
			return
		}

		// Find and update goal
		found := false
		now := models.Now()
		for i, goal := range user.Memory.Goals {
			if goal.ID == goalID {
				user.Memory.Goals[i].Status = req.Status
				user.Memory.Goals[i].UpdatedAt = now
				if req.Status == "completed" {
					user.Memory.Goals[i].CompletedAt = &now
				}
				found = true
				break
			}
		}

		if !found {
			c.JSON(http.StatusNotFound, gin.H{"error": "goal not found"})
			return
		}

		// Update user document
		updates := map[string]interface{}{
			"memory.goals":      user.Memory.Goals,
			"memory.updated_at": now,
			"updated_at":        now,
		}
		if err := fs.UpdateUser(ctx, uid, updates); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update goal"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "updated"})
	}
}

// Helper function to generate memory IDs
func generateMemoryID(prefix string) string {
	return prefix + "_" + models.Now().Format("20060102150405")
}
