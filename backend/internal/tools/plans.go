package tools

import (
	"context"
	"fmt"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"simon-backend/internal/models"
)

// PlanService handles plan operations
type PlanService struct {
	fs *firestore.Client
}

// NewPlanService creates a new plan service
func NewPlanService(fs *firestore.Client) *PlanService {
	return &PlanService{fs: fs}
}

// PlanCreateRequest represents a plan creation request
type PlanCreateRequest struct {
	UID     string       `json:"uid"`
	CoachID string       `json:"coach_id"`
	Plan    models.Plan  `json:"plan"`
}

// PlanCreateResponse represents a plan creation response
type PlanCreateResponse struct {
	PlanID string `json:"plan_id"`
	Status string `json:"status"`
}

// PlanUpdateRequest represents a plan update request
type PlanUpdateRequest struct {
	UID     string                 `json:"uid"`
	PlanID  string                 `json:"plan_id"`
	Updates map[string]interface{} `json:"updates"`
}

// PlanUpdateResponse represents a plan update response
type PlanUpdateResponse struct {
	Status string `json:"status"`
}

// PlanListRequest represents a plan list request
type PlanListRequest struct {
	UID   string `json:"uid"`
	Limit int    `json:"limit"`
}

// PlanListResponse represents a plan list response
type PlanListResponse struct {
	Plans []models.Plan `json:"plans"`
}

// Create creates a new plan with validation
func (s *PlanService) Create(ctx context.Context, req PlanCreateRequest) (*PlanCreateResponse, error) {
	// Validate plan constraints
	if len(req.Plan.NextActions) > 12 {
		return nil, fmt.Errorf("too many next actions (max 12, got %d)", len(req.Plan.NextActions))
	}
	if len(req.Plan.Milestones) > 8 {
		return nil, fmt.Errorf("too many milestones (max 8, got %d)", len(req.Plan.Milestones))
	}

	// Validate horizon
	validHorizons := map[string]bool{
		"today":   true,
		"week":    true,
		"month":   true,
		"quarter": true,
	}
	if !validHorizons[req.Plan.Horizon] {
		return nil, fmt.Errorf("invalid horizon: %s (must be today, week, month, or quarter)", req.Plan.Horizon)
	}

	// Validate required fields
	if req.Plan.Title == "" {
		return nil, fmt.Errorf("plan title is required")
	}
	if req.Plan.Objective == "" {
		return nil, fmt.Errorf("plan objective is required")
	}

	// Generate plan ID
	planRef := s.fs.Collection("plans").NewDoc()
	planID := planRef.ID

	// Set plan fields
	plan := req.Plan
	plan.ID = planID
	plan.UID = req.UID
	plan.CoachID = req.CoachID
	plan.Status = "active"
	plan.CreatedAt = models.Now()
	plan.UpdatedAt = models.Now()

	// Set IDs for milestones and next actions
	for i := range plan.Milestones {
		if plan.Milestones[i].ID == "" {
			plan.Milestones[i].ID = fmt.Sprintf("milestone_%d", i+1)
		}
		if plan.Milestones[i].Status == "" {
			plan.Milestones[i].Status = "pending"
		}
	}

	for i := range plan.NextActions {
		if plan.NextActions[i].ID == "" {
			plan.NextActions[i].ID = fmt.Sprintf("action_%d", i+1)
		}
		if plan.NextActions[i].Status == "" {
			plan.NextActions[i].Status = "pending"
		}
	}

	// Create plan document
	if _, err := planRef.Set(ctx, plan); err != nil {
		return nil, fmt.Errorf("failed to create plan: %w", err)
	}

	return &PlanCreateResponse{
		PlanID: planID,
		Status: "created",
	}, nil
}

// Update updates an existing plan
func (s *PlanService) Update(ctx context.Context, req PlanUpdateRequest) (*PlanUpdateResponse, error) {
	// Verify plan ownership
	planDoc, err := s.fs.Collection("plans").Doc(req.PlanID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("plan not found: %w", err)
	}

	var plan models.Plan
	if err := planDoc.DataTo(&plan); err != nil {
		return nil, fmt.Errorf("failed to parse plan: %w", err)
	}

	if plan.UID != req.UID {
		return nil, fmt.Errorf("unauthorized: plan belongs to different user")
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
		// Validate constraints for specific fields
		if key == "next_actions" {
			if actions, ok := value.([]interface{}); ok && len(actions) > 12 {
				return nil, fmt.Errorf("too many next actions (max 12)")
			}
		}
		if key == "milestones" {
			if milestones, ok := value.([]interface{}); ok && len(milestones) > 8 {
				return nil, fmt.Errorf("too many milestones (max 8)")
			}
		}

		updates = append(updates, firestore.Update{
			Path:  key,
			Value: value,
		})
	}

	// Apply updates
	if _, err := s.fs.Collection("plans").Doc(req.PlanID).Update(ctx, updates); err != nil {
		return nil, fmt.Errorf("failed to update plan: %w", err)
	}

	return &PlanUpdateResponse{
		Status: "updated",
	}, nil
}

// ListActive returns active plans for a user
func (s *PlanService) ListActive(ctx context.Context, req PlanListRequest) (*PlanListResponse, error) {
	limit := req.Limit
	if limit == 0 {
		limit = 10
	}

	query := s.fs.Collection("plans").
		Where("uid", "==", req.UID).
		Where("status", "==", "active").
		OrderBy("created_at", firestore.Desc).
		Limit(limit)

	iter := query.Documents(ctx)
	defer iter.Stop()

	plans := []models.Plan{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to iterate plans: %w", err)
		}

		var plan models.Plan
		if err := doc.DataTo(&plan); err != nil {
			return nil, fmt.Errorf("failed to parse plan: %w", err)
		}

		plans = append(plans, plan)
	}

	return &PlanListResponse{
		Plans: plans,
	}, nil
}

// ValidateAgainstCoachSpec validates a plan against CoachSpec output schema
func (s *PlanService) ValidateAgainstCoachSpec(plan models.Plan, coachSpec *models.CoachSpec) error {
	if coachSpec == nil {
		return nil // No validation if no CoachSpec
	}

	// Get Plan schema
	planSchema := coachSpec.Outputs.Schemas.Plan
	
	// Validate max items constraints from CoachSpec
	if props, ok := planSchema.Properties["milestones"].(map[string]interface{}); ok {
		if maxItems, ok := props["maxItems"].(float64); ok {
			if len(plan.Milestones) > int(maxItems) {
				return fmt.Errorf("too many milestones (max %d per CoachSpec)", int(maxItems))
			}
		}
	}

	if props, ok := planSchema.Properties["next_actions"].(map[string]interface{}); ok {
		if maxItems, ok := props["maxItems"].(float64); ok {
			if len(plan.NextActions) > int(maxItems) {
				return fmt.Errorf("too many next actions (max %d per CoachSpec)", int(maxItems))
			}
		}
	}

	return nil
}
