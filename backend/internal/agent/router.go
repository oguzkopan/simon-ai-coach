package agent

import (
	"context"
	"encoding/json"
	"fmt"

	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
)

// RouteResult contains the result of routing a moment
type RouteResult struct {
	CoachID      *string // nil if new coach generated
	CoachName    string
	Title        string // Session title
	FirstMessage *string
}

// Router is the main agent that routes moments to appropriate coaches
type Router struct {
	gemini    *gemini.Client
	firestore *firestore.Client
}

// NewRouter creates a new router agent
func NewRouter(gm *gemini.Client, fs *firestore.Client) *Router {
	return &Router{
		gemini:    gm,
		firestore: fs,
	}
}

// Route analyzes the user's prompt and routes to appropriate coach
func (r *Router) Route(ctx context.Context, uid string, prompt string) (*RouteResult, error) {
	// Step 1: Classify intent
	intent, err := r.classifyIntent(ctx, prompt)
	if err != nil {
		return nil, fmt.Errorf("failed to classify intent: %w", err)
	}

	// Step 2: Find existing coach or generate new one
	var coachID *string
	var coachName string
	var blueprint map[string]interface{}

	if intent.ExistingCoachID != nil {
		// Use existing coach
		coach, err := r.firestore.GetCoach(ctx, *intent.ExistingCoachID)
		if err != nil {
			// Fallback to generating new coach
			coachName, blueprint = r.generateCoach(intent)
		} else {
			coachID = &coach.ID
			coachName = coach.Title
			blueprint = coach.Blueprint
		}
	} else if intent.GenerateCoach {
		// Generate new coach dynamically
		coachName, blueprint = r.generateCoach(intent)
	} else {
		// Fallback to general coach
		coachName = "General Systems Coach"
		blueprint = r.getDefaultBlueprint()
	}

	// Step 3: Generate first message/question
	firstMessage, err := r.generateFirstMessage(ctx, prompt, coachName, blueprint)
	if err != nil {
		// Non-fatal, can be nil
		firstMessage = nil
	}

	// Step 4: Generate session title
	title := r.generateTitle(intent, coachName)

	return &RouteResult{
		CoachID:      coachID,
		CoachName:    coachName,
		Title:        title,
		FirstMessage: firstMessage,
	}, nil
}

// Intent represents the classified user intent
type Intent struct {
	Category        string  `json:"category"`         // focus, planning, decision, creativity, health, confidence
	Urgency         string  `json:"urgency"`          // high, medium, low
	ExistingCoachID *string `json:"existing_coach_id"` // nil if no match
	GenerateCoach   bool    `json:"generate_coach"`
	Tone            string  `json:"tone"` // calm_direct, warm_supportive, socratic
}

// classifyIntent uses Gemini to classify the user's intent
func (r *Router) classifyIntent(ctx context.Context, prompt string) (*Intent, error) {
	systemPrompt := `You are Simon's routing agent. Analyze the user's prompt and classify their intent.

Return a JSON object with:
{
  "category": "focus" | "planning" | "decision" | "creativity" | "health" | "confidence",
  "urgency": "high" | "medium" | "low",
  "existing_coach_id": null (for now, we'll implement coach matching later),
  "generate_coach": true | false,
  "tone": "calm_direct" | "warm_supportive" | "socratic"
}

Categories:
- focus: Stuck, need next step, clarify action
- planning: Structure day/week, organize tasks
- decision: Make a choice, weigh options
- creativity: Generate ideas, brainstorm
- health: Reset, recover, self-care
- confidence: Motivation, encouragement

Be decisive. If unsure, default to "focus" with "calm_direct" tone.`

	userPrompt := fmt.Sprintf("User prompt: %s", prompt)

	response, err := r.gemini.GenerateContent(ctx, systemPrompt, userPrompt)
	if err != nil {
		return nil, err
	}

	// Parse JSON response
	var intent Intent
	if err := json.Unmarshal([]byte(response), &intent); err != nil {
		// Fallback to default intent
		return &Intent{
			Category:      "focus",
			Urgency:       "medium",
			GenerateCoach: true,
			Tone:          "calm_direct",
		}, nil
	}

	return &intent, nil
}

// generateCoach creates a dynamic coach blueprint based on intent
func (r *Router) generateCoach(intent *Intent) (string, map[string]interface{}) {
	var name string

	switch intent.Category {
	case "focus":
		name = "Focus Sprint Coach"
	case "planning":
		name = "Planning Coach"
	case "decision":
		name = "Decision Coach"
	case "creativity":
		name = "Creative Coach"
	case "health":
		name = "Reset Coach"
	case "confidence":
		name = "Confidence Coach"
	default:
		name = "General Systems Coach"
	}

	blueprint := map[string]interface{}{
		"version": "1.0",
		"style": map[string]interface{}{
			"tone":          intent.Tone,
			"questionStyle": "single_question_first",
		},
		"rules": map[string]interface{}{
			"alwaysAskOneClarifyingQuestionFirst": true,
			"defaultAnswerShape":                  "three_steps",
			"offerSystemWhenUseful":               true,
			"respectContextVault":                 true,
		},
		"framework": map[string]interface{}{
			"name": intent.Category,
		},
		"safety": map[string]interface{}{
			"noMedicalLegalClaims":              true,
			"encourageProfessionalHelpWhenNeeded": true,
		},
	}

	return name, blueprint
}

// getDefaultBlueprint returns a default coach blueprint
func (r *Router) getDefaultBlueprint() map[string]interface{} {
	return map[string]interface{}{
		"version": "1.0",
		"style": map[string]interface{}{
			"tone":          "calm_direct",
			"questionStyle": "single_question_first",
		},
		"rules": map[string]interface{}{
			"alwaysAskOneClarifyingQuestionFirst": true,
			"defaultAnswerShape":                  "three_steps",
			"offerSystemWhenUseful":               true,
			"respectContextVault":                 true,
		},
	}
}

// generateFirstMessage generates the coach's first message/question
func (r *Router) generateFirstMessage(ctx context.Context, userPrompt string, coachName string, blueprint map[string]interface{}) (*string, error) {
	systemPrompt := fmt.Sprintf(`You are %s. The user just started a moment with this prompt: "%s"

Based on your coaching style, ask ONE clarifying question to understand their situation better.
Keep it short (1-2 sentences). Be warm and direct.`, coachName, userPrompt)

	response, err := r.gemini.GenerateContent(ctx, systemPrompt, "Generate your first question:")
	if err != nil {
		return nil, err
	}

	return &response, nil
}

// generateTitle generates a session title based on intent
func (r *Router) generateTitle(intent *Intent, coachName string) string {
	// Simple title generation
	// Could be enhanced with Gemini later
	return fmt.Sprintf("%s - Moment", coachName)
}
