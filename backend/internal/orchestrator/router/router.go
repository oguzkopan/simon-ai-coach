package router

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"simon-backend/internal/gemini"
)

// Route represents the classified routing decision
type Route struct {
	Name         string   // "quick_nudge", "deep_session", "make_a_system", "review_retro", "scheduling"
	Confidence   float64  // 0.0-1.0
	NeedsPlanner bool     // Whether to invoke planner agent
	ContextKeys  []string // Context to fetch: "active_plans", "last_session_summary", "values", "commitments"
	ToolIDs      []string // Tools that might be needed
}

// RouterAgent classifies user intent and determines routing
type RouterAgent struct {
	geminiClient *gemini.Client
}

// NewRouterAgent creates a new router agent
func NewRouterAgent(gm *gemini.Client) *RouterAgent {
	return &RouterAgent{
		geminiClient: gm,
	}
}

// Classify analyzes the user message and returns routing decision
func (r *RouterAgent) Classify(ctx context.Context, userMessage string, uid string) (*Route, error) {
	prompt := r.buildClassificationPrompt(userMessage)

	response, err := r.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return nil, fmt.Errorf("gemini classification failed: %w", err)
	}

	// Parse JSON response
	var rawRoute struct {
		Route        string  `json:"route"`
		Confidence   float64 `json:"confidence"`
		NeedsPlanner bool    `json:"needs_planner"`
	}

	if err := json.Unmarshal([]byte(response), &rawRoute); err != nil {
		// Fallback to default route
		return r.getDefaultRoute(), nil
	}

	// Build full route with context keys and tools
	route := &Route{
		Name:         rawRoute.Route,
		Confidence:   rawRoute.Confidence,
		NeedsPlanner: rawRoute.NeedsPlanner,
	}

	// Set context keys based on route
	switch route.Name {
	case "quick_nudge":
		route.ContextKeys = []string{"values"}
		route.NeedsPlanner = false
		route.ToolIDs = []string{}

	case "deep_session":
		route.ContextKeys = []string{"values", "active_plans", "last_session_summary"}
		route.NeedsPlanner = true
		route.ToolIDs = []string{"memory_read", "memory_write", "plan_create"}

	case "make_a_system":
		route.ContextKeys = []string{"values", "active_plans"}
		route.NeedsPlanner = true
		route.ToolIDs = []string{"plan_create", "checkin_schedule"}

	case "review_retro":
		route.ContextKeys = []string{"active_plans", "commitments", "last_session_summary"}
		route.NeedsPlanner = true
		route.ToolIDs = []string{"memory_read", "plan_update"}

	case "scheduling":
		route.ContextKeys = []string{"active_plans"}
		route.NeedsPlanner = false
		route.ToolIDs = []string{"calendar_event_create", "reminder_create", "local_notification_schedule"}

	default:
		// Default to quick nudge
		route.Name = "quick_nudge"
		route.ContextKeys = []string{"values"}
		route.NeedsPlanner = false
	}

	return route, nil
}

// buildClassificationPrompt creates the prompt for intent classification
func (r *RouterAgent) buildClassificationPrompt(userMessage string) string {
	return fmt.Sprintf(`Classify the user's intent into one of these routes:

Routes:
1. quick_nudge: User wants a quick tip, nudge, or simple action (< 5 min)
   - Examples: "I'm stuck", "What should I do next?", "Give me a quick win"
   
2. deep_session: User wants to work through a problem deeply
   - Examples: "I need to figure out my strategy", "Help me think through this", "I'm overwhelmed"
   
3. make_a_system: User wants to build a repeatable system or routine
   - Examples: "Help me create a morning routine", "I need a system for X", "How do I make this automatic?"
   
4. review_retro: User wants to review progress or do a retrospective
   - Examples: "Let's review my week", "What did I accomplish?", "Weekly review time"
   
5. scheduling: User wants to schedule something specific
   - Examples: "Remind me to X", "Add this to my calendar", "Schedule a check-in"

User message: "%s"

Respond with JSON only:
{
  "route": "quick_nudge" | "deep_session" | "make_a_system" | "review_retro" | "scheduling",
  "confidence": 0.0-1.0,
  "needs_planner": true | false
}

Be decisive. If unsure, default to "quick_nudge" with confidence 0.5.`, userMessage)
}

// getDefaultRoute returns a safe default route
func (r *RouterAgent) getDefaultRoute() *Route {
	return &Route{
		Name:         "quick_nudge",
		Confidence:   0.5,
		NeedsPlanner: false,
		ContextKeys:  []string{"values"},
		ToolIDs:      []string{},
	}
}

// IsHighConfidence returns true if confidence is above threshold
func (r *Route) IsHighConfidence() bool {
	return r.Confidence >= 0.7
}

// RequiresContext returns true if route needs context fetching
func (r *Route) RequiresContext() bool {
	return len(r.ContextKeys) > 0
}

// String returns a human-readable route description
func (r *Route) String() string {
	return fmt.Sprintf("%s (confidence: %.2f, planner: %v)", 
		strings.ReplaceAll(r.Name, "_", " "), 
		r.Confidence, 
		r.NeedsPlanner)
}
