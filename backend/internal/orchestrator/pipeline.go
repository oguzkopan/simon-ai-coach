package orchestrator

import (
	"context"
	"fmt"
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
	SessionID   string
	CoachID     string
	UserMessage string
	UID         string
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
		coachAgent:     coach.NewCoachAgent(gm),
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

		// Step 1: Router Agent - Classify intent (OPTIMIZED: Skip for most messages)
		// Only use router for specific keywords to save API quota
		route := p.getQuickRoute(input.UserMessage)
		
		// Only call router API if message contains specific keywords
		if p.shouldUseRouter(input.UserMessage) {
			routeResult, err := p.router.Classify(ctx, input.UserMessage, input.UID)
			if err != nil {
				// Fallback to default route instead of failing
				fmt.Printf("Router classification failed (using default): %v\n", err)
			} else {
				route = routeResult
			}
		}

		// Step 2: Context Builder - Fetch relevant context (including conversation history)
		contextPacket, err := p.contextBuilder.Build(ctx, input.UID, input.CoachID, input.SessionID, route)
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
		coachOutput, err := p.coachAgent.Generate(ctx, input.UserMessage, contextPacket, stream)
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
			if err := p.memoryAgent.Update(context.Background(), input.SessionID, input.UID, coachOutput); err != nil {
				// Log error but don't fail the request
				fmt.Printf("Memory update failed: %v\n", err)
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

// shouldUseRouter determines if we should call the router API
// This saves API quota by only routing when necessary
func (p *Pipeline) shouldUseRouter(message string) bool {
	// Keywords that indicate complex routing needs
	keywords := []string{
		"review", "retro", "retrospective", "weekly",
		"system", "routine", "habit", "schedule",
		"plan", "strategy", "roadmap",
	}
	
	messageLower := strings.ToLower(message)
	for _, keyword := range keywords {
		if strings.Contains(messageLower, keyword) {
			return true
		}
	}
	
	return false
}

// getQuickRoute returns a default route for simple conversations
func (p *Pipeline) getQuickRoute(message string) *router.Route {
	return &router.Route{
		Name:         "quick_nudge",
		Confidence:   0.8,
		NeedsPlanner: false,
		ContextKeys:  []string{"values"},
		ToolIDs:      []string{},
	}
}
