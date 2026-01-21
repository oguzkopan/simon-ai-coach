package planner

import (
	"context"
	"encoding/json"
	"fmt"

	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator/coach"
)

// PlannerOutput contains structured outputs extracted from coaching
type PlannerOutput struct {
	Plan         *models.Plan
	NextActions  []models.NextAction
	WeeklyReview *models.WeeklyReview
}

// PlannerAgent extracts structured data from coaching responses
type PlannerAgent struct {
	geminiClient *gemini.Client
}

// NewPlannerAgent creates a new planner agent
func NewPlannerAgent(gm *gemini.Client) *PlannerAgent {
	return &PlannerAgent{
		geminiClient: gm,
	}
}

// Generate extracts structured outputs from coach response
func (pa *PlannerAgent) Generate(
	ctx context.Context,
	coachOutput *coach.CoachOutput,
	spec *models.CoachSpec,
) (*PlannerOutput, error) {
	// Build extraction prompt
	prompt := pa.buildExtractionPrompt(coachOutput.MessageText, spec)

	// Generate structured output
	response, err := pa.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return nil, fmt.Errorf("gemini extraction failed: %w", err)
	}

	// Parse JSON response
	var output PlannerOutput
	if err := json.Unmarshal([]byte(response), &output); err != nil {
		// Try to extract individual components
		output = pa.fallbackExtraction(response)
	}

	// Validate and enforce constraints
	if output.Plan != nil {
		output.Plan = pa.validatePlan(output.Plan, spec)
	}

	if len(output.NextActions) > 0 {
		output.NextActions = pa.validateNextActions(output.NextActions, spec)
	}

	return &output, nil
}

// buildExtractionPrompt creates the prompt for structured extraction
func (pa *PlannerAgent) buildExtractionPrompt(coachText string, spec *models.CoachSpec) string {
	return fmt.Sprintf(`Extract structured data from this coaching response.

Coach response:
%s

Extract any of the following that are present:

1. Plan (if the coach created a plan):
{
  "title": "string",
  "objective": "string",
  "horizon": "today" | "week" | "month" | "quarter",
  "milestones": [
    {
      "label": "string",
      "due_date_hint": "string",
      "success_metric": "string"
    }
  ],
  "next_actions": [...]
}

2. NextActions (if the coach suggested specific actions):
[
  {
    "id": "string",
    "title": "string",
    "duration_min": number,
    "energy": "low" | "medium" | "high",
    "when": {
      "kind": "now" | "today_window" | "schedule_exact",
      "start_iso": "ISO8601 string (optional)",
      "end_iso": "ISO8601 string (optional)"
    }
  }
]

3. WeeklyReview (if this was a review session):
{
  "wins": ["string"],
  "misses": ["string"],
  "root_causes": ["string"],
  "next_week_focus": ["string"],
  "commitments": [...]
}

Constraints:
- Max 8 milestones per plan
- Max 12 next actions per plan
- Max 7 next actions in standalone list

Respond with JSON only. If nothing to extract, return empty object {}.`, coachText)
}

// validatePlan enforces plan constraints
func (pa *PlannerAgent) validatePlan(plan *models.Plan, spec *models.CoachSpec) *models.Plan {
	// Enforce max milestones
	if len(plan.Milestones) > 8 {
		plan.Milestones = plan.Milestones[:8]
	}

	// Enforce max next actions
	if len(plan.NextActions) > 12 {
		plan.NextActions = plan.NextActions[:12]
	}

	return plan
}

// validateNextActions enforces next action constraints
func (pa *PlannerAgent) validateNextActions(actions []models.NextAction, spec *models.CoachSpec) []models.NextAction {
	// Enforce max actions
	if len(actions) > 7 {
		actions = actions[:7]
	}

	// Validate each action
	for i := range actions {
		// Ensure ID is set
		if actions[i].ID == "" {
			actions[i].ID = fmt.Sprintf("na_%d", i+1)
		}

		// Ensure energy level is valid
		if actions[i].Energy != "low" && actions[i].Energy != "medium" && actions[i].Energy != "high" {
			actions[i].Energy = "medium"
		}

		// Ensure when.kind is valid
		if actions[i].When.Kind != "now" && actions[i].When.Kind != "today_window" && actions[i].When.Kind != "schedule_exact" {
			actions[i].When.Kind = "now"
		}
	}

	return actions
}

// fallbackExtraction attempts to extract data when JSON parsing fails
func (pa *PlannerAgent) fallbackExtraction(response string) PlannerOutput {
	// Simple fallback: return empty output
	// In production, this would use more sophisticated parsing
	return PlannerOutput{}
}

// ExtractNextActions is a convenience method to extract only next actions
func (pa *PlannerAgent) ExtractNextActions(ctx context.Context, coachText string) ([]models.NextAction, error) {
	prompt := fmt.Sprintf(`Extract next actions from this coaching response.

Coach response:
%s

Return a JSON array of next actions:
[
  {
    "id": "string",
    "title": "string",
    "duration_min": number,
    "energy": "low" | "medium" | "high",
    "when": {
      "kind": "now" | "today_window" | "schedule_exact"
    }
  }
]

Max 7 actions. If none found, return empty array [].`, coachText)

	response, err := pa.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return nil, err
	}

	var actions []models.NextAction
	if err := json.Unmarshal([]byte(response), &actions); err != nil {
		return []models.NextAction{}, nil
	}

	// Validate
	if len(actions) > 7 {
		actions = actions[:7]
	}

	return actions, nil
}
