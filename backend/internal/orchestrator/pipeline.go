package orchestrator

import (
	"context"
	"fmt"
	"log"
	"strings"

	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator/coach"
	orchestratorContext "simon-backend/internal/orchestrator/context"
	"simon-backend/internal/orchestrator/memory"
	"simon-backend/internal/orchestrator/planner"
	"simon-backend/internal/orchestrator/router"
	"simon-backend/internal/orchestrator/safety"
)

// SSEEvent represents a server-sent event (alias to coach.SSEEvent)
type SSEEvent = coach.SSEEvent

// Pipeline orchestrates the multi-agent coaching flow
type Pipeline struct {
	router         *router.RouterAgent
	contextBuilder *orchestratorContext.ContextBuilder
	coachAgent     *coach.CoachAgent
	plannerAgent   *planner.PlannerAgent
	safetyFilter   *safety.SafetyFilter
	memoryAgent    *memory.MemoryAgent
}

// PipelineInput contains the input for pipeline execution
type PipelineInput struct {
	SessionID     string
	CoachID       string
	UserMessage   string
	Attachments   []models.Attachment
	UID           string
	UserTimezone  string // User's timezone (e.g., "America/New_York")
	UserLocalTime string // User's current local time in ISO 8601
	AudioData     []byte // Optional audio data for voice messages
}

// PipelineOutput contains the output stream and session data
type PipelineOutput struct {
	Stream      chan SSEEvent
	SessionData *models.Session
}

// NewPipeline creates a new orchestration pipeline
func NewPipeline(fs *firestore.Client, gm *gemini.Client) *Pipeline {
	return &Pipeline{
		router:         router.NewRouterAgent(gm),
		contextBuilder: orchestratorContext.NewContextBuilder(fs, gm),
		coachAgent:     coach.NewCoachAgent(gm, fs.DB),
		plannerAgent:   planner.NewPlannerAgent(gm),
		safetyFilter:   safety.NewSafetyFilter(),
		memoryAgent:    memory.NewMemoryAgent(fs, gm),
	}
}

// Execute runs the full multi-agent pipeline
func (p *Pipeline) Execute(ctx context.Context, input PipelineInput) (*PipelineOutput, error) {
	stream := make(chan SSEEvent, 100)

	go func() {
		defer close(stream)

		// Log audio data received by pipeline
		if len(input.AudioData) > 0 {
			log.Printf("🎵 Pipeline received %d bytes of audio data", len(input.AudioData))
		}

		// Step 1: Router Agent - DISABLED to save API quota
		// Use simple default route instead of calling Gemini for classification
		route := p.getDefaultRoute(input.UserMessage)

		// Step 2: Context Builder - Fetch relevant context (including conversation history)
		contextPacket, err := p.contextBuilder.Build(ctx, input.UID, input.CoachID, input.SessionID, route, input.UserTimezone, input.UserLocalTime)
		if err != nil {
			stream <- SSEEvent{
				Type: "error",
				Data: map[string]interface{}{
					"code":    "CONTEXT_ERROR",
					"message": fmt.Sprintf("Failed to build context: %v", err),
				},
			}
			return
		}

		// Step 3: Coach Agent - Generate streaming response
		// Pass audio data if available
		if len(input.AudioData) > 0 {
			log.Printf("🎵 Pipeline calling GenerateWithAudio with %d bytes", len(input.AudioData))
		} else {
			log.Printf("⚠️ Pipeline calling GenerateWithAudio with NO audio data")
		}
		coachOutput, err := p.coachAgent.GenerateWithAudio(ctx, input.UserMessage, input.Attachments, input.AudioData, contextPacket, stream)
		if err != nil {
			stream <- SSEEvent{
				Type: "error",
				Data: map[string]interface{}{
					"code":    "COACH_ERROR",
					"message": fmt.Sprintf("Failed to generate response: %v", err),
				},
			}
			return
		}

		// Step 4: Planner Agent - Extract structured outputs (if needed)
		if route.NeedsPlanner {
			plannerOutput, err := p.plannerAgent.Generate(ctx, coachOutput, contextPacket.CoachSpec)
			if err != nil {
				// Non-fatal error, log but continue
				stream <- SSEEvent{
					Type: "policy.notice",
					Data: map[string]interface{}{
						"kind":    "planner_warning",
						"message": "Could not extract structured plan",
					},
				}
			} else {
				// Emit structured cards
				if plannerOutput.Plan != nil {
					stream <- SSEEvent{
						Type: "card.plan",
						Data: map[string]interface{}{
							"schema": "Plan.v1",
							"plan":   plannerOutput.Plan,
						},
					}
				}

				if len(plannerOutput.NextActions) > 0 {
					stream <- SSEEvent{
						Type: "card.next_actions",
						Data: map[string]interface{}{
							"schema": "NextAction.v1",
							"items":  plannerOutput.NextActions,
						},
					}
				}

				if plannerOutput.WeeklyReview != nil {
					stream <- SSEEvent{
						Type: "card.weekly_review",
						Data: map[string]interface{}{
							"schema": "WeeklyReview.v1",
							"review": plannerOutput.WeeklyReview,
						},
					}
				}
			}
		}

		// Step 5: Safety Filter - Validate output
		if err := p.safetyFilter.Validate(ctx, coachOutput, contextPacket.CoachSpec); err != nil {
			stream <- SSEEvent{
				Type: "policy.notice",
				Data: map[string]interface{}{
					"kind":    "safety_boundary",
					"message": err.Error(),
				},
			}
		}

		// Step 6: Memory Agent - Update user memory asynchronously
		go func() {
			if err := p.memoryAgent.Update(context.Background(), input.SessionID, input.UID, input.CoachID, coachOutput); err != nil {
				// Log error but don't fail the request
				log.Printf("Memory update failed: %v", err)
			} else {
				log.Printf("Memory updated successfully for user %s", input.UID)
			}
		}()

		// Send completion event
		stream <- SSEEvent{
			Type: "stream.done",
			Data: map[string]interface{}{
				"status": "ok",
			},
		}
	}()

	return &PipelineOutput{
		Stream:      stream,
		SessionData: nil,
	}, nil
}

// getDefaultRoute returns a default route based on simple keyword matching
// This avoids making extra API calls to save quota
func (p *Pipeline) getDefaultRoute(message string) *router.Route {
	messageLower := strings.ToLower(message)

	// Check for review/retrospective keywords
	if strings.Contains(messageLower, "review") ||
		strings.Contains(messageLower, "retro") ||
		strings.Contains(messageLower, "retrospective") ||
		strings.Contains(messageLower, "weekly") {
		return &router.Route{
			Name:         "review_retro",
			Confidence:   0.8,
			NeedsPlanner: true,
			ContextKeys:  []string{"active_plans", "commitments", "last_session_summary"},
			ToolIDs:      []string{"memory_read", "plan_update"},
		}
	}

	// Check for system/routine keywords
	if strings.Contains(messageLower, "system") ||
		strings.Contains(messageLower, "routine") ||
		strings.Contains(messageLower, "habit") {
		return &router.Route{
			Name:         "make_a_system",
			Confidence:   0.8,
			NeedsPlanner: true,
			ContextKeys:  []string{"values", "active_plans"},
			ToolIDs:      []string{"plan_create", "checkin_schedule"},
		}
	}

	// Check for scheduling keywords
	if strings.Contains(messageLower, "schedule") ||
		strings.Contains(messageLower, "remind") ||
		strings.Contains(messageLower, "calendar") {
		return &router.Route{
			Name:         "scheduling",
			Confidence:   0.8,
			NeedsPlanner: false,
			ContextKeys:  []string{"active_plans"},
			ToolIDs:      []string{"calendar_event_create", "reminder_create", "local_notification_schedule"},
		}
	}

	// Check for deep session keywords
	if strings.Contains(messageLower, "plan") ||
		strings.Contains(messageLower, "strategy") ||
		strings.Contains(messageLower, "help me think") ||
		strings.Contains(messageLower, "overwhelmed") {
		return &router.Route{
			Name:         "deep_session",
			Confidence:   0.8,
			NeedsPlanner: true,
			ContextKeys:  []string{"values", "active_plans", "last_session_summary"},
			ToolIDs:      []string{"memory_read", "memory_write", "plan_create"},
		}
	}

	// Default to quick nudge
	return &router.Route{
		Name:         "quick_nudge",
		Confidence:   0.8,
		NeedsPlanner: false,
		ContextKeys:  []string{"values"},
		ToolIDs:      []string{},
	}
}
