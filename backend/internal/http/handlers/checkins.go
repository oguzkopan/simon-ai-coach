package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/tools"
)

// ScheduleCheckin handles POST /v1/checkins
func ScheduleCheckin(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)

		var req struct {
			CoachID string                `json:"coach_id" binding:"required"`
			Cadence models.CheckinCadence `json:"cadence" binding:"required"`
			Channel string                `json:"channel" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		checkinService := tools.NewCheckinService(fs.DB)

		resp, err := checkinService.Schedule(c.Request.Context(), tools.CheckinScheduleRequest{
			UID:     uid,
			CoachID: req.CoachID,
			Cadence: req.Cadence,
			Channel: req.Channel,
		})
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"checkin_id": resp.CheckinID,
			"status":     resp.Status,
		})
	}
}

// ListCheckins handles GET /v1/checkins
func ListCheckins(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)

		checkinService := tools.NewCheckinService(fs.DB)

		resp, err := checkinService.List(c.Request.Context(), tools.CheckinListRequest{
			UID: uid,
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, resp.Checkins)
	}
}

// UpdateCheckin handles PUT /v1/checkins/:id
func UpdateCheckin(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		checkinID := c.Param("id")

		if checkinID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "checkin id is required"})
			return
		}

		var req struct {
			Updates map[string]interface{} `json:"updates" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		checkinService := tools.NewCheckinService(fs.DB)

		resp, err := checkinService.Update(c.Request.Context(), tools.CheckinUpdateRequest{
			UID:       uid,
			CheckinID: checkinID,
			Updates:   req.Updates,
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

// DeleteCheckin handles DELETE /v1/checkins/:id
func DeleteCheckin(fs *firestore.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)
		checkinID := c.Param("id")

		if checkinID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "checkin id is required"})
			return
		}

		checkinService := tools.NewCheckinService(fs.DB)

		if err := checkinService.Delete(c.Request.Context(), uid, checkinID); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status": "deleted",
		})
	}
}

