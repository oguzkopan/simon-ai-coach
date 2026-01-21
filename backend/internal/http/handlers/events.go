package handlers

import (
	"net/http"
	"strconv"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"google.golang.org/api/iterator"

	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/logger"
	"simon-backend/internal/models"
)

// EventsHandler handles event-related endpoints
type EventsHandler struct {
	fs  *fsClient.Client
	log *logger.Logger
}

// NewEventsHandler creates a new events handler
func NewEventsHandler(fs *fsClient.Client, log *logger.Logger) *EventsHandler {
	return &EventsHandler{
		fs:  fs,
		log: log,
	}
}

// ListCalendarEvents handles GET /v1/events/calendar
// Query params: coach_id (optional), status (optional), limit (default 50), offset (default 0)
func (h *EventsHandler) ListCalendarEvents(c *gin.Context) {
	uid := middleware.GetUID(c)
	ctx := c.Request.Context()

	// Parse query parameters
	coachID := c.Query("coach_id")
	status := c.Query("status")
	
	// Parse limit with default 50
	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}
	
	// Parse offset with default 0
	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	h.log.Info(ctx, "ListCalendarEvents", map[string]interface{}{
		"uid":      uid,
		"coach_id": coachID,
		"status":   status,
		"limit":    limit,
		"offset":   offset,
	})

	// Build query - filter by uid and order by start_iso ascending
	query := h.fs.DB.Collection("calendar_events").
		Where("uid", "==", uid).
		OrderBy("start_iso", firestore.Asc)

	// Apply optional filters
	if coachID != "" {
		query = query.Where("coach_id", "==", coachID)
	}
	
	if status != "" {
		query = query.Where("status", "==", status)
	}

	// Apply limit
	query = query.Limit(limit)

	// Apply offset
	if offset > 0 {
		query = query.Offset(offset)
	}

	// Execute query
	iter := query.Documents(ctx)
	defer iter.Stop()

	var events []models.CalendarEvent
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			h.log.Error(ctx, "Error iterating calendar events", err, map[string]interface{}{
				"uid": uid,
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list calendar events"})
			return
		}

		var event models.CalendarEvent
		if err := doc.DataTo(&event); err != nil {
			h.log.Error(ctx, "Error parsing calendar event", err, map[string]interface{}{
				"doc_id": doc.Ref.ID,
				"uid":    uid,
			})
			continue
		}
		events = append(events, event)
	}

	h.log.Info(ctx, "ListCalendarEvents success", map[string]interface{}{
		"uid":   uid,
		"count": len(events),
	})

	// Return empty array if no events found
	if len(events) == 0 {
		c.JSON(http.StatusOK, []models.CalendarEvent{})
	} else {
		c.JSON(http.StatusOK, events)
	}
}

// ListReminders handles GET /v1/events/reminders
// Query params: coach_id (optional), status (optional), limit (default 50), offset (default 0)
func (h *EventsHandler) ListReminders(c *gin.Context) {
	uid := middleware.GetUID(c)
	ctx := c.Request.Context()

	// Parse query parameters
	coachID := c.Query("coach_id")
	status := c.Query("status")
	
	// Parse limit with default 50
	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}
	
	// Parse offset with default 0
	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	h.log.Info(ctx, "ListReminders", map[string]interface{}{
		"uid":      uid,
		"coach_id": coachID,
		"status":   status,
		"limit":    limit,
		"offset":   offset,
	})

	// Build query - filter by uid and order by created_at descending
	query := h.fs.DB.Collection("reminders").
		Where("uid", "==", uid).
		OrderBy("created_at", firestore.Desc)

	// Apply optional filters
	if coachID != "" {
		query = query.Where("coach_id", "==", coachID)
	}
	
	if status != "" {
		query = query.Where("status", "==", status)
	}

	// Apply limit
	query = query.Limit(limit)

	// Apply offset
	if offset > 0 {
		query = query.Offset(offset)
	}

	// Execute query
	iter := query.Documents(ctx)
	defer iter.Stop()

	var reminders []models.Reminder
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			h.log.Error(ctx, "Error iterating reminders", err, map[string]interface{}{
				"uid": uid,
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list reminders"})
			return
		}

		var reminder models.Reminder
		if err := doc.DataTo(&reminder); err != nil {
			h.log.Error(ctx, "Error parsing reminder", err, map[string]interface{}{
				"doc_id": doc.Ref.ID,
				"uid":    uid,
			})
			continue
		}
		reminders = append(reminders, reminder)
	}

	h.log.Info(ctx, "ListReminders success", map[string]interface{}{
		"uid":   uid,
		"count": len(reminders),
	})

	// Return empty array if no reminders found
	if len(reminders) == 0 {
		c.JSON(http.StatusOK, []models.Reminder{})
	} else {
		c.JSON(http.StatusOK, reminders)
	}
}

// ListScheduledNotifications handles GET /v1/events/notifications
// Query params: coach_id (optional), status (optional), limit (default 50), offset (default 0)
func (h *EventsHandler) ListScheduledNotifications(c *gin.Context) {
	uid := middleware.GetUID(c)
	ctx := c.Request.Context()

	// Parse query parameters
	coachID := c.Query("coach_id")
	status := c.Query("status")
	
	// Parse limit with default 50
	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}
	
	// Parse offset with default 0
	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	h.log.Info(ctx, "ListScheduledNotifications", map[string]interface{}{
		"uid":      uid,
		"coach_id": coachID,
		"status":   status,
		"limit":    limit,
		"offset":   offset,
	})

	// Build query - filter by uid and order by created_at descending
	query := h.fs.DB.Collection("scheduled_notifications").
		Where("uid", "==", uid).
		OrderBy("created_at", firestore.Desc)

	// Apply optional filters
	if coachID != "" {
		query = query.Where("coach_id", "==", coachID)
	}
	
	if status != "" {
		query = query.Where("status", "==", status)
	}

	// Apply limit
	query = query.Limit(limit)

	// Apply offset
	if offset > 0 {
		query = query.Offset(offset)
	}

	// Execute query
	iter := query.Documents(ctx)
	defer iter.Stop()

	var notifications []models.ScheduledNotification
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			h.log.Error(ctx, "Error iterating scheduled notifications", err, map[string]interface{}{
				"uid": uid,
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list scheduled notifications"})
			return
		}

		var notification models.ScheduledNotification
		if err := doc.DataTo(&notification); err != nil {
			h.log.Error(ctx, "Error parsing scheduled notification", err, map[string]interface{}{
				"doc_id": doc.Ref.ID,
				"uid":    uid,
			})
			continue
		}
		notifications = append(notifications, notification)
	}

	h.log.Info(ctx, "ListScheduledNotifications success", map[string]interface{}{
		"uid":   uid,
		"count": len(notifications),
	})

	// Return empty array if no notifications found
	if len(notifications) == 0 {
		c.JSON(http.StatusOK, []models.ScheduledNotification{})
	} else {
		c.JSON(http.StatusOK, notifications)
	}
}

// CompleteReminder handles PUT /v1/events/reminders/:id/complete
// Marks a reminder as completed with ownership validation
func (h *EventsHandler) CompleteReminder(c *gin.Context) {
	uid := middleware.GetUID(c)
	ctx := c.Request.Context()
	reminderID := c.Param("id")

	if reminderID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "reminder id is required"})
		return
	}

	h.log.Info(ctx, "CompleteReminder", map[string]interface{}{
		"uid":         uid,
		"reminder_id": reminderID,
	})

	// Get the reminder document reference
	docRef := h.fs.DB.Collection("reminders").Doc(reminderID)

	// Get the reminder to verify ownership
	doc, err := docRef.Get(ctx)
	if err != nil {
		h.log.Error(ctx, "Error getting reminder", err, map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusNotFound, gin.H{"error": "reminder not found"})
		return
	}

	// Parse the reminder
	var reminder models.Reminder
	if err := doc.DataTo(&reminder); err != nil {
		h.log.Error(ctx, "Error parsing reminder", err, map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse reminder"})
		return
	}

	// Verify ownership
	if reminder.UID != uid {
		h.log.Warning(ctx, "Unauthorized reminder completion attempt", map[string]interface{}{
			"uid":          uid,
			"reminder_id":  reminderID,
			"reminder_uid": reminder.UID,
		})
		c.JSON(http.StatusForbidden, gin.H{"error": "you do not have permission to complete this reminder"})
		return
	}

	// Check if already completed
	if reminder.Status == "completed" {
		h.log.Info(ctx, "Reminder already completed", map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusOK, reminder)
		return
	}

	// Update the reminder
	now := firestore.ServerTimestamp
	completedAt := firestore.ServerTimestamp
	updates := []firestore.Update{
		{Path: "status", Value: "completed"},
		{Path: "completed_at", Value: completedAt},
		{Path: "updated_at", Value: now},
	}

	if _, err := docRef.Update(ctx, updates); err != nil {
		h.log.Error(ctx, "Error updating reminder", err, map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to complete reminder"})
		return
	}

	// Get the updated reminder
	updatedDoc, err := docRef.Get(ctx)
	if err != nil {
		h.log.Error(ctx, "Error getting updated reminder", err, map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get updated reminder"})
		return
	}

	var updatedReminder models.Reminder
	if err := updatedDoc.DataTo(&updatedReminder); err != nil {
		h.log.Error(ctx, "Error parsing updated reminder", err, map[string]interface{}{
			"uid":         uid,
			"reminder_id": reminderID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse updated reminder"})
		return
	}

	h.log.Info(ctx, "CompleteReminder success", map[string]interface{}{
		"uid":         uid,
		"reminder_id": reminderID,
	})

	c.JSON(http.StatusOK, updatedReminder)
}

// CancelNotification handles DELETE /v1/events/notifications/:id
// Cancels a scheduled notification with ownership validation
func (h *EventsHandler) CancelNotification(c *gin.Context) {
	uid := middleware.GetUID(c)
	ctx := c.Request.Context()
	notificationID := c.Param("id")

	if notificationID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "notification id is required"})
		return
	}

	h.log.Info(ctx, "CancelNotification", map[string]interface{}{
		"uid":             uid,
		"notification_id": notificationID,
	})

	// Get the notification document reference
	docRef := h.fs.DB.Collection("scheduled_notifications").Doc(notificationID)

	// Get the notification to verify ownership
	doc, err := docRef.Get(ctx)
	if err != nil {
		h.log.Error(ctx, "Error getting notification", err, map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusNotFound, gin.H{"error": "notification not found"})
		return
	}

	// Parse the notification
	var notification models.ScheduledNotification
	if err := doc.DataTo(&notification); err != nil {
		h.log.Error(ctx, "Error parsing notification", err, map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse notification"})
		return
	}

	// Verify ownership
	if notification.UID != uid {
		h.log.Warning(ctx, "Unauthorized notification cancellation attempt", map[string]interface{}{
			"uid":              uid,
			"notification_id":  notificationID,
			"notification_uid": notification.UID,
		})
		c.JSON(http.StatusForbidden, gin.H{"error": "you do not have permission to cancel this notification"})
		return
	}

	// Check if already cancelled
	if notification.Status == "cancelled" {
		h.log.Info(ctx, "Notification already cancelled", map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusOK, notification)
		return
	}

	// Update the notification
	now := firestore.ServerTimestamp
	updates := []firestore.Update{
		{Path: "status", Value: "cancelled"},
		{Path: "updated_at", Value: now},
	}

	if _, err := docRef.Update(ctx, updates); err != nil {
		h.log.Error(ctx, "Error updating notification", err, map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to cancel notification"})
		return
	}

	// Get the updated notification
	updatedDoc, err := docRef.Get(ctx)
	if err != nil {
		h.log.Error(ctx, "Error getting updated notification", err, map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get updated notification"})
		return
	}

	var updatedNotification models.ScheduledNotification
	if err := updatedDoc.DataTo(&updatedNotification); err != nil {
		h.log.Error(ctx, "Error parsing updated notification", err, map[string]interface{}{
			"uid":             uid,
			"notification_id": notificationID,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse updated notification"})
		return
	}

	h.log.Info(ctx, "CancelNotification success", map[string]interface{}{
		"uid":             uid,
		"notification_id": notificationID,
	})

	c.JSON(http.StatusOK, updatedNotification)
}
