package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/tools"
)

// ListPlans returns active plans for the authenticated user
func ListPlans(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)

		// Parse query parameters
		limit := 10 // default
		if limitStr := c.Query("limit"); limitStr != "" {
			if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
				limit = parsedLimit
			}
		}

		// Note: status parameter is ignored for now since we only support "active" status
		// In the future, we could add support for "completed", "archived", etc.

		fmt.Printf("📋 ListPlans: uid=%s, limit=%d\n", uid, limit)

		planService := tools.NewPlanService(fs.DB)
		
		resp, err := planService.ListActive(c.Request.Context(), tools.PlanListRequest{
			UID:   uid,
			Limit: limit,
		})
		if err != nil {
			fmt.Printf("❌ ListPlans error: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		fmt.Printf("✅ ListPlans: returning %d plans\n", len(resp.Plans))
		c.JSON(http.StatusOK, resp.Plans)
	}
}

// CreatePlan creates a new plan
func CreatePlan(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)

		var req struct {
			CoachID string       `json:"coach_id" binding:"required"`
			Plan    models.Plan  `json:"plan" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		planService := tools.NewPlanService(fs.DB)
		
		resp, err := planService.Create(c.Request.Context(), tools.PlanCreateRequest{
			UID:     uid,
			CoachID: req.CoachID,
			Plan:    req.Plan,
		})
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"plan_id": resp.PlanID,
			"status":  resp.Status,
		})
	}
}

// UpdatePlan updates an existing plan
func UpdatePlan(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		planID := c.Param("id")

		if planID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "plan id is required"})
			return
		}

		var req struct {
			Updates map[string]interface{} `json:"updates" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			fmt.Printf("❌ UpdatePlan bind error: %v\n", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request: " + err.Error()})
			return
		}

		fmt.Printf("📝 UpdatePlan: planID=%s, uid=%s, updates=%+v\n", planID, uid, req.Updates)

		planService := tools.NewPlanService(fs.DB)
		
		resp, err := planService.Update(c.Request.Context(), tools.PlanUpdateRequest{
			UID:     uid,
			PlanID:  planID,
			Updates: req.Updates,
		})
		if err != nil {
			fmt.Printf("❌ UpdatePlan service error: %v\n", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		fmt.Printf("✅ UpdatePlan: planID=%s, status=%s\n", planID, resp.Status)
		c.JSON(http.StatusOK, gin.H{
			"status": resp.Status,
		})
	}
}

// GetPlan returns a specific plan by ID
func GetPlan(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		planID := c.Param("id")

		if planID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "plan id is required"})
			return
		}

		// Fetch plan from Firestore
		doc, err := fs.DB.Collection("plans").Doc(planID).Get(c.Request.Context())
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "plan not found"})
			return
		}

		// Get raw data and clean string due_dates
		data := doc.Data()
		if milestones, ok := data["milestones"].([]interface{}); ok {
			for _, m := range milestones {
				if milestone, ok := m.(map[string]interface{}); ok {
					if dueDate, exists := milestone["due_date"]; exists {
						if _, isString := dueDate.(string); isString {
							delete(milestone, "due_date")
						}
					}
				}
			}
		}
		
		// Clean next_actions completed_at and when timestamps
		if nextActions, ok := data["next_actions"].([]interface{}); ok {
			for _, a := range nextActions {
				if action, ok := a.(map[string]interface{}); ok {
					if completedAt, exists := action["completed_at"]; exists {
						if _, isString := completedAt.(string); isString {
							delete(action, "completed_at")
						}
					}
					// Also clean when.start_iso and when.end_iso if they are strings
					if whenData, ok := action["when"].(map[string]interface{}); ok {
						if startISO, exists := whenData["start_iso"]; exists {
							if _, isString := startISO.(string); isString {
								delete(whenData, "start_iso")
							}
						}
						if endISO, exists := whenData["end_iso"]; exists {
							if _, isString := endISO.(string); isString {
								delete(whenData, "end_iso")
							}
						}
					}
				}
			}
		}

		var plan models.Plan
		// Manually populate plan from cleaned data
		plan.ID = doc.Ref.ID
		// Initialize slices to empty arrays instead of nil
		plan.Milestones = []models.Milestone{}
		plan.NextActions = []models.NextAction{}
		if uid, ok := data["uid"].(string); ok {
			plan.UID = uid
		}
		if coachID, ok := data["coach_id"].(string); ok {
			plan.CoachID = coachID
		}
		if title, ok := data["title"].(string); ok {
			plan.Title = title
		}
		if objective, ok := data["objective"].(string); ok {
			plan.Objective = objective
		}
		if horizon, ok := data["horizon"].(string); ok {
			plan.Horizon = horizon
		}
		if status, ok := data["status"].(string); ok {
			plan.Status = status
		}
		if createdAt, ok := data["created_at"].(time.Time); ok {
			plan.CreatedAt = createdAt
		}
		if updatedAt, ok := data["updated_at"].(time.Time); ok {
			plan.UpdatedAt = updatedAt
		}
		
		// Handle milestones
		if milestones, ok := data["milestones"].([]interface{}); ok {
			for _, m := range milestones {
				if milestoneData, ok := m.(map[string]interface{}); ok {
					milestone := models.Milestone{}
					if id, ok := milestoneData["id"].(string); ok {
						milestone.ID = id
					}
					if title, ok := milestoneData["title"].(string); ok {
						milestone.Title = title
					}
					if desc, ok := milestoneData["description"].(string); ok {
						milestone.Description = desc
					}
					if status, ok := milestoneData["status"].(string); ok {
						milestone.Status = status
					}
					if dueDate, ok := milestoneData["due_date"].(time.Time); ok {
						milestone.DueDate = &dueDate
					}
					plan.Milestones = append(plan.Milestones, milestone)
				}
			}
		}
		
		// Handle next_actions
		if nextActions, ok := data["next_actions"].([]interface{}); ok {
			for _, a := range nextActions {
				if actionData, ok := a.(map[string]interface{}); ok {
					action := models.NextAction{}
					if id, ok := actionData["id"].(string); ok {
						action.ID = id
					}
					if title, ok := actionData["title"].(string); ok {
						action.Title = title
					}
					if duration, ok := actionData["duration_min"].(int64); ok {
						action.DurationMin = int(duration)
					}
					if energy, ok := actionData["energy"].(string); ok {
						action.Energy = energy
					}
					if status, ok := actionData["status"].(string); ok {
						action.Status = status
					}
					if completedAt, ok := actionData["completed_at"].(time.Time); ok {
						action.CompletedAt = &completedAt
					}
					
					// Handle when field
					if whenData, ok := actionData["when"].(map[string]interface{}); ok {
						when := &models.When{}
						if kind, ok := whenData["kind"].(string); ok {
							when.Kind = kind
						}
						if startISO, ok := whenData["start_iso"].(time.Time); ok {
							when.StartISO = &startISO
						}
						if endISO, ok := whenData["end_iso"].(time.Time); ok {
							when.EndISO = &endISO
						}
						action.When = when
					}
					
					plan.NextActions = append(plan.NextActions, action)
				}
			}
		}

		// Verify ownership
		if plan.UID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "unauthorized"})
			return
		}

		c.JSON(http.StatusOK, plan)
	}
}
