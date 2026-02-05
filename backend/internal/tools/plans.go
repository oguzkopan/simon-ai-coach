package tools

import (
	"context"
	"fmt"
	"time"

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
	fmt.Printf("🔧 PlanService.Update: planID=%s, uid=%s\n", req.PlanID, req.UID)
	
	// Verify plan ownership
	planDoc, err := s.fs.Collection("plans").Doc(req.PlanID).Get(ctx)
	if err != nil {
		fmt.Printf("❌ Failed to get plan: %v\n", err)
		return nil, fmt.Errorf("plan not found: %w", err)
	}

	// Get raw data and clean string dates
	data := planDoc.Data()
	
	// Clean milestone due_date strings
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
	
	// Clean next_actions completed_at strings
	if nextActions, ok := data["next_actions"].([]interface{}); ok {
		for _, a := range nextActions {
			if action, ok := a.(map[string]interface{}); ok {
				if completedAt, exists := action["completed_at"]; exists {
					if _, isString := completedAt.(string); isString {
						fmt.Printf("🧹 Cleaning string completed_at from action\n")
						delete(action, "completed_at")
					}
				}
				// Also clean when.start_iso and when.end_iso if they are strings
				if whenData, ok := action["when"].(map[string]interface{}); ok {
					if startISO, exists := whenData["start_iso"]; exists {
						if _, isString := startISO.(string); isString {
							fmt.Printf("🧹 Cleaning string start_iso from when\n")
							delete(whenData, "start_iso")
						}
					}
					if endISO, exists := whenData["end_iso"]; exists {
						if _, isString := endISO.(string); isString {
							fmt.Printf("🧹 Cleaning string end_iso from when\n")
							delete(whenData, "end_iso")
						}
					}
				}
			}
		}
	}

	// Manually populate plan from cleaned data instead of using DataTo
	var plan models.Plan
	plan.ID = planDoc.Ref.ID
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

	if plan.UID != req.UID {
		fmt.Printf("❌ Unauthorized: plan.UID=%s, req.UID=%s\n", plan.UID, req.UID)
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
		fmt.Printf("📝 Processing update: key=%s, value type=%T\n", key, value)
		
		// Validate constraints for specific fields
		if key == "next_actions" {
			if actions, ok := value.([]interface{}); ok {
				fmt.Printf("📝 next_actions count: %d\n", len(actions))
				if len(actions) > 12 {
					return nil, fmt.Errorf("too many next actions (max 12)")
				}
			}
		}
		if key == "milestones" {
			if milestones, ok := value.([]interface{}); ok {
				fmt.Printf("📝 milestones count: %d\n", len(milestones))
				if len(milestones) > 8 {
					return nil, fmt.Errorf("too many milestones (max 8)")
				}
			}
		}

		updates = append(updates, firestore.Update{
			Path:  key,
			Value: value,
		})
	}

	// Apply updates
	fmt.Printf("✅ Applying %d updates to plan %s\n", len(updates), req.PlanID)
	if _, err := s.fs.Collection("plans").Doc(req.PlanID).Update(ctx, updates); err != nil {
		fmt.Printf("❌ Failed to apply updates: %v\n", err)
		return nil, fmt.Errorf("failed to update plan: %w", err)
	}

	fmt.Printf("✅ Plan updated successfully: %s\n", req.PlanID)
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

		// Get raw data
		data := doc.Data()
		
		// Pre-process milestones to handle string due_dates
		if milestones, ok := data["milestones"].([]interface{}); ok {
			for _, m := range milestones {
				if milestone, ok := m.(map[string]interface{}); ok {
					// Remove string due_date fields (they'll be nil in the struct)
					if dueDate, exists := milestone["due_date"]; exists {
						if _, isString := dueDate.(string); isString {
							delete(milestone, "due_date")
						}
					}
				}
			}
		}
		
		// Now manually populate plan from cleaned data
		var plan models.Plan
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
					// due_date is already removed if it was a string
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

		plans = append(plans, plan)
	}

	fmt.Printf("📋 ListActive: uid=%s, limit=%d, found=%d plans\n", req.UID, limit, len(plans))

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
