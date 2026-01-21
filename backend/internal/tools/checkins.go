package tools

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"simon-backend/internal/models"
)

// CheckinService handles check-in scheduling operations
type CheckinService struct {
	fs *firestore.Client
}

// NewCheckinService creates a new checkin service
func NewCheckinService(fs *firestore.Client) *CheckinService {
	return &CheckinService{fs: fs}
}

// CheckinScheduleRequest represents a check-in schedule request
type CheckinScheduleRequest struct {
	UID     string                `json:"uid"`
	CoachID string                `json:"coach_id"`
	Cadence models.CheckinCadence `json:"cadence"`
	Channel string                `json:"channel"` // "in_app" | "local_notification_proposal"
}

// CheckinScheduleResponse represents a check-in schedule response
type CheckinScheduleResponse struct {
	CheckinID string `json:"checkin_id"`
	Status    string `json:"status"`
}

// CheckinListRequest represents a check-in list request
type CheckinListRequest struct {
	UID string `json:"uid"`
}

// CheckinListResponse represents a check-in list response
type CheckinListResponse struct {
	Checkins []models.Checkin `json:"checkins"`
}

// CheckinUpdateRequest represents a check-in update request
type CheckinUpdateRequest struct {
	UID       string                 `json:"uid"`
	CheckinID string                 `json:"checkin_id"`
	Updates   map[string]interface{} `json:"updates"`
}

// CheckinUpdateResponse represents a check-in update response
type CheckinUpdateResponse struct {
	Status string `json:"status"`
}

// Schedule creates a new check-in schedule
func (s *CheckinService) Schedule(ctx context.Context, req CheckinScheduleRequest) (*CheckinScheduleResponse, error) {
	// Validate cadence
	validKinds := map[string]bool{
		"daily":       true,
		"weekdays":    true,
		"weekly":      true,
		"custom_cron": true,
	}
	if !validKinds[req.Cadence.Kind] {
		return nil, fmt.Errorf("invalid cadence kind: %s", req.Cadence.Kind)
	}

	// Validate channel
	validChannels := map[string]bool{
		"in_app":                       true,
		"local_notification_proposal":  true,
	}
	if !validChannels[req.Channel] {
		return nil, fmt.Errorf("invalid channel: %s", req.Channel)
	}

	// Validate hour and minute
	if req.Cadence.Hour < 0 || req.Cadence.Hour > 23 {
		return nil, fmt.Errorf("invalid hour: %d (must be 0-23)", req.Cadence.Hour)
	}
	if req.Cadence.Minute < 0 || req.Cadence.Minute > 59 {
		return nil, fmt.Errorf("invalid minute: %d (must be 0-59)", req.Cadence.Minute)
	}

	// Generate checkin ID
	checkinRef := s.fs.Collection("checkins").NewDoc()
	checkinID := checkinRef.ID

	// Calculate next run time
	nextRunAt := s.calculateNextRun(req.Cadence, time.Now())

	// Create checkin document
	checkin := models.Checkin{
		ID:        checkinID,
		UID:       req.UID,
		CoachID:   req.CoachID,
		Cadence:   req.Cadence,
		Channel:   req.Channel,
		NextRunAt: nextRunAt,
		Status:    "active",
		CreatedAt: models.Now(),
		UpdatedAt: models.Now(),
	}

	if _, err := checkinRef.Set(ctx, checkin); err != nil {
		return nil, fmt.Errorf("failed to create checkin: %w", err)
	}

	// TODO: Schedule Cloud Task for check-in execution
	// This would be implemented when Cloud Tasks integration is added

	return &CheckinScheduleResponse{
		CheckinID: checkinID,
		Status:    "scheduled",
	}, nil
}

// List returns all check-ins for a user
func (s *CheckinService) List(ctx context.Context, req CheckinListRequest) (*CheckinListResponse, error) {
	query := s.fs.Collection("checkins").
		Where("uid", "==", req.UID).
		Where("status", "==", "active").
		OrderBy("next_run_at", firestore.Asc)

	iter := query.Documents(ctx)
	defer iter.Stop()

	checkins := []models.Checkin{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to iterate checkins: %w", err)
		}

		var checkin models.Checkin
		if err := doc.DataTo(&checkin); err != nil {
			return nil, fmt.Errorf("failed to parse checkin: %w", err)
		}

		checkins = append(checkins, checkin)
	}

	return &CheckinListResponse{
		Checkins: checkins,
	}, nil
}

// Update updates an existing check-in
func (s *CheckinService) Update(ctx context.Context, req CheckinUpdateRequest) (*CheckinUpdateResponse, error) {
	// Verify checkin ownership
	checkinDoc, err := s.fs.Collection("checkins").Doc(req.CheckinID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("checkin not found: %w", err)
	}

	var checkin models.Checkin
	if err := checkinDoc.DataTo(&checkin); err != nil {
		return nil, fmt.Errorf("failed to parse checkin: %w", err)
	}

	if checkin.UID != req.UID {
		return nil, fmt.Errorf("unauthorized: checkin belongs to different user")
	}

	// Build Firestore updates
	updates := []firestore.Update{
		{
			Path:  "updated_at",
			Value: models.Now(),
		},
	}

	// Add user-provided updates
	for key, value := range req.Updates {
		updates = append(updates, firestore.Update{
			Path:  key,
			Value: value,
		})
	}

	// Apply updates
	if _, err := s.fs.Collection("checkins").Doc(req.CheckinID).Update(ctx, updates); err != nil {
		return nil, fmt.Errorf("failed to update checkin: %w", err)
	}

	return &CheckinUpdateResponse{
		Status: "updated",
	}, nil
}

// Delete deletes a check-in
func (s *CheckinService) Delete(ctx context.Context, uid, checkinID string) error {
	// Verify checkin ownership
	checkinDoc, err := s.fs.Collection("checkins").Doc(checkinID).Get(ctx)
	if err != nil {
		return fmt.Errorf("checkin not found: %w", err)
	}

	var checkin models.Checkin
	if err := checkinDoc.DataTo(&checkin); err != nil {
		return fmt.Errorf("failed to parse checkin: %w", err)
	}

	if checkin.UID != uid {
		return fmt.Errorf("unauthorized: checkin belongs to different user")
	}

	// Soft delete by setting status to deleted
	updates := []firestore.Update{
		{
			Path:  "status",
			Value: "deleted",
		},
		{
			Path:  "updated_at",
			Value: models.Now(),
		},
	}

	if _, err := s.fs.Collection("checkins").Doc(checkinID).Update(ctx, updates); err != nil {
		return fmt.Errorf("failed to delete checkin: %w", err)
	}

	return nil
}

// calculateNextRun calculates the next run time based on cadence
func (s *CheckinService) calculateNextRun(cadence models.CheckinCadence, from time.Time) time.Time {
	// Get user's timezone (default to UTC for now)
	loc := time.UTC

	// Start with today at the specified time
	now := from.In(loc)
	nextRun := time.Date(now.Year(), now.Month(), now.Day(), cadence.Hour, cadence.Minute, 0, 0, loc)

	// If the time has already passed today, start from tomorrow
	if nextRun.Before(now) {
		nextRun = nextRun.AddDate(0, 0, 1)
	}

	switch cadence.Kind {
	case "daily":
		// Already set to next occurrence

	case "weekdays":
		// Skip to next weekday (Mon-Fri)
		for {
			weekday := nextRun.Weekday()
			if weekday >= time.Monday && weekday <= time.Friday {
				break
			}
			nextRun = nextRun.AddDate(0, 0, 1)
		}

	case "weekly":
		// Find next occurrence of specified weekdays
		if len(cadence.Weekdays) > 0 {
			// Convert weekdays to Go's time.Weekday (0=Sunday, 6=Saturday)
			targetWeekdays := make(map[time.Weekday]bool)
			for _, wd := range cadence.Weekdays {
				// Input: 1=Sun, 2=Mon, ..., 7=Sat
				// Convert to Go: 0=Sun, 1=Mon, ..., 6=Sat
				goWeekday := time.Weekday((wd - 1) % 7)
				targetWeekdays[goWeekday] = true
			}

			// Find next matching weekday
			for i := 0; i < 7; i++ {
				if targetWeekdays[nextRun.Weekday()] {
					break
				}
				nextRun = nextRun.AddDate(0, 0, 1)
			}
		}

	case "custom_cron":
		// TODO: Implement cron parsing
		// For now, default to daily
	}

	return nextRun
}
