package handlers

import (
	"fmt"
	"net/http"
	"strconv"

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
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		planService := tools.NewPlanService(fs.DB)
		
		resp, err := planService.Update(c.Request.Context(), tools.PlanUpdateRequest{
			UID:     uid,
			PlanID:  planID,
			Updates: req.Updates,
		})
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

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

		var plan models.Plan
		if err := doc.DataTo(&plan); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse plan"})
			return
		}

		// Verify ownership
		if plan.UID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "unauthorized"})
			return
		}

		c.JSON(http.StatusOK, plan)
	}
}
