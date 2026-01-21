package context

import (
	"context"
	"fmt"

	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator/router"
)

// ContextPacket contains all context needed for coaching
type ContextPacket struct {
	User          *models.User
	CoachSpec     *models.CoachSpec
	ActivePlans   []models.Plan
	RecentSummary string
	RetrievalHits []MemoryHit
}

// MemoryHit represents a memory search result
type MemoryHit struct {
	Type    string  // "commitment", "preference", "note", "session_summary"
	ID      string
	Snippet string
	Score   float64
}

// ContextBuilder builds context packets for coaching sessions
type ContextBuilder struct {
	fs           *firestore.Client
	geminiClient *gemini.Client
}

// NewContextBuilder creates a new context builder
func NewContextBuilder(fs *firestore.Client, gm *gemini.Client) *ContextBuilder {
	return &ContextBuilder{
		fs:           fs,
		geminiClient: gm,
	}
}

// Build constructs a complete context packet
func (cb *ContextBuilder) Build(ctx context.Context, uid string, coachID string, route *router.Route) (*ContextPacket, error) {
	packet := &ContextPacket{}

	// Fetch user
	user, err := cb.getUserDoc(ctx, uid)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	packet.User = user

	// Fetch coach spec
	coachSpec, err := cb.getCoachSpec(ctx, coachID)
	if err != nil {
		// Use default coach spec if not found
		coachSpec = cb.getDefaultCoachSpec()
	}
	packet.CoachSpec = coachSpec

	// Fetch context based on route needs
	for _, key := range route.ContextKeys {
		switch key {
		case "active_plans":
			plans, err := cb.getActivePlans(ctx, uid)
			if err == nil {
				packet.ActivePlans = plans
			}

		case "last_session_summary":
			summary, err := cb.getLastSessionSummary(ctx, uid)
			if err == nil {
				packet.RecentSummary = summary
			}

		case "values":
			// Already in user document
			// No additional fetch needed

		case "commitments":
			// Already in user document
			// No additional fetch needed
		}
	}

	return packet, nil
}

// getUserDoc fetches the user document
func (cb *ContextBuilder) getUserDoc(ctx context.Context, uid string) (*models.User, error) {
	user, err := cb.fs.GetUser(ctx, uid)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// getCoachSpec fetches the coach specification
func (cb *ContextBuilder) getCoachSpec(ctx context.Context, coachID string) (*models.CoachSpec, error) {
	coach, err := cb.fs.GetCoach(ctx, coachID)
	if err != nil {
		return nil, err
	}

	// Extract CoachSpec from coach
	// For now, return a basic spec based on blueprint
	// TODO: Update when CoachSpec field is added to Coach model
	return cb.blueprintToCoachSpec(coach.Blueprint), nil
}

// getActivePlans fetches active plans for the user
func (cb *ContextBuilder) getActivePlans(ctx context.Context, uid string) ([]models.Plan, error) {
	// Query plans collection
	// TODO: Implement when plans collection is created
	// For now, return empty slice
	return []models.Plan{}, nil
}

// getLastSessionSummary fetches the most recent session summary
func (cb *ContextBuilder) getLastSessionSummary(ctx context.Context, uid string) (string, error) {
	// Query sessions collection for most recent summary
	// TODO: Implement when session summaries are stored
	// For now, return empty string
	return "", nil
}

// getDefaultCoachSpec returns a default coach specification
func (cb *ContextBuilder) getDefaultCoachSpec() *models.CoachSpec {
	return &models.CoachSpec{
		Version: "1.0",
		Identity: models.Identity{
			Name:    "General Systems Coach",
			Tagline: "Build small systems that compound",
			Niche:   "productivity_systems",
		},
		Style: models.Style{
			Tone:      "minimalist_direct",
			Verbosity: "low",
			Formatting: models.Formatting{
				MaxBullets:               7,
				MaxSentencesPerParagraph: 2,
				AlwaysEndWith:            []string{"one_question", "one_next_action"},
				UseEmoji:                 "sparingly",
				AllowedMarkdown:          []string{"bullet_list", "numbered_list", "bold"},
			},
			InteractionRules: models.InteractionRules{
				AskOneQuestionAtATime:   true,
				ConfirmBeforeScheduling: true,
				AvoidMotivationalFluff:  true,
				ReflectUserLanguage:     true,
			},
		},
		Policies: models.Policies{
			Refusals: models.Refusals{
				Medical:         true,
				Legal:           true,
				FinancialAdvice: "general_only",
				SelfHarm:        "escalate_support",
			},
			Privacy: models.Privacy{
				StoreSensitiveMemory: false,
				RedactPatterns:       []string{"password", "api_key", "credit_card"},
			},
			Safety: models.Safety{
				NoManipulation: true,
				NoGuilt:        true,
				NoShaming:      true,
			},
		},
		ToolsAllowed: models.ToolsAllowed{
			ClientTools: []string{
				"local_notification_schedule",
				"calendar_event_create",
				"reminder_create",
			},
			ServerTools: []string{
				"memory_read",
				"memory_write",
				"plan_create",
			},
			RequiresUserConfirmation: []string{
				"calendar_event_create",
				"reminder_create",
				"local_notification_schedule",
			},
		},
	}
}

// blueprintToCoachSpec converts old blueprint format to CoachSpec
func (cb *ContextBuilder) blueprintToCoachSpec(blueprint map[string]interface{}) *models.CoachSpec {
	// For backward compatibility, convert blueprint to CoachSpec
	// This is a temporary solution until all coaches use CoachSpec
	spec := cb.getDefaultCoachSpec()

	// Extract style if present
	if style, ok := blueprint["style"].(map[string]interface{}); ok {
		if tone, ok := style["tone"].(string); ok {
			spec.Style.Tone = tone
		}
	}

	return spec
}
