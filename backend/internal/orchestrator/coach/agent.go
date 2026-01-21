package coach

import (
	"context"
	"fmt"
	"strings"
	"time"

	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
	orchestratorContext "simon-backend/internal/orchestrator/context"
)

// CoachOutput represents the output from the coach agent
type CoachOutput struct {
	MessageText    string
	ToolRequests   []ToolRequest
	StructuredData map[string]interface{}
}

// ToolRequest represents a tool execution request
type ToolRequest struct {
	RequestID             string
	Tool                  string
	RequiresConfirmation  bool
	Reason                string
	Payload               map[string]interface{}
}

// SSEEvent represents a server-sent event
type SSEEvent struct {
	Type string
	Data map[string]interface{}
}

// CoachAgent generates coaching responses using CoachSpec
type CoachAgent struct {
	geminiClient *gemini.Client
}

// NewCoachAgent creates a new coach agent
func NewCoachAgent(gm *gemini.Client) *CoachAgent {
	return &CoachAgent{
		geminiClient: gm,
	}
}

// Generate creates a streaming coaching response
func (ca *CoachAgent) Generate(
	ctx context.Context,
	userMessage string,
	contextPacket *orchestratorContext.ContextPacket,
	stream chan<- SSEEvent,
) (*CoachOutput, error) {
	// Build system prompt from CoachSpec
	systemPrompt := ca.buildSystemPrompt(contextPacket.CoachSpec, contextPacket.User, contextPacket.ActivePlans)

	// Combine system prompt with user message
	fullPrompt := systemPrompt + "\n\nUser: " + userMessage

	// Send stream.open event
	stream <- SSEEvent{
		Type: "stream.open",
		Data: map[string]interface{}{
			"session_id":      generateSessionID(),
			"server_time_iso": time.Now().UTC().Format(time.RFC3339),
		},
	}

	// Generate streaming response from Gemini
	fullText := ""
	tokenChan, errChan := ca.geminiClient.GenerateContentStream(ctx, fullPrompt)

	// Stream tokens
	for {
		select {
		case token, ok := <-tokenChan:
			if !ok {
				// Stream finished
				goto streamDone
			}
			fullText += token
			stream <- SSEEvent{
				Type: "message.delta",
				Data: map[string]interface{}{
					"role":  "assistant",
					"delta": token,
				},
			}

		case err := <-errChan:
			if err != nil {
				return nil, fmt.Errorf("gemini stream failed: %w", err)
			}
		}
	}

streamDone:

	// Send message.final event
	stream <- SSEEvent{
		Type: "message.final",
		Data: map[string]interface{}{
			"message_id":   generateMessageID(),
			"role":         "assistant",
			"text":         fullText,
			"render_hints": map[string]interface{}{"max_cards": 3},
		},
	}

	// Parse tool requests from response (if any)
	toolRequests := ca.parseToolRequests(fullText, contextPacket.CoachSpec)
	for _, toolReq := range toolRequests {
		stream <- SSEEvent{
			Type: "tool.request",
			Data: map[string]interface{}{
				"request_id":            toolReq.RequestID,
				"tool":                  toolReq.Tool,
				"requires_confirmation": toolReq.RequiresConfirmation,
				"reason":                toolReq.Reason,
				"payload":               toolReq.Payload,
			},
		}
	}

	return &CoachOutput{
		MessageText:  fullText,
		ToolRequests: toolRequests,
	}, nil
}

// buildSystemPrompt constructs the system prompt from CoachSpec
func (ca *CoachAgent) buildSystemPrompt(
	spec *models.CoachSpec,
	user *models.User,
	plans []models.Plan,
) string {
	var prompt strings.Builder

	// Identity
	prompt.WriteString(fmt.Sprintf("You are %s, a %s coach.\n\n",
		spec.Identity.Name,
		spec.Identity.Niche))

	if spec.Identity.Tagline != "" {
		prompt.WriteString(fmt.Sprintf("Tagline: %s\n\n", spec.Identity.Tagline))
	}

	// Style
	prompt.WriteString("Your style:\n")
	prompt.WriteString(fmt.Sprintf("- Tone: %s\n", spec.Style.Tone))
	prompt.WriteString(fmt.Sprintf("- Verbosity: %s\n", spec.Style.Verbosity))

	if len(spec.Style.Formatting.AlwaysEndWith) > 0 {
		prompt.WriteString(fmt.Sprintf("- Always end with: %v\n", spec.Style.Formatting.AlwaysEndWith))
	}

	prompt.WriteString("\n")

	// Interaction rules
	prompt.WriteString("Interaction rules:\n")
	if spec.Style.InteractionRules.AskOneQuestionAtATime {
		prompt.WriteString("- Ask one question at a time\n")
	}
	if spec.Style.InteractionRules.ConfirmBeforeScheduling {
		prompt.WriteString("- Confirm before scheduling\n")
	}
	if spec.Style.InteractionRules.AvoidMotivationalFluff {
		prompt.WriteString("- Avoid motivational fluff\n")
	}
	if spec.Style.InteractionRules.ReflectUserLanguage {
		prompt.WriteString("- Reflect user's language\n")
	}
	prompt.WriteString("\n")

	// User context
	if user != nil {
		prompt.WriteString("User context:\n")
		if len(user.ContextVault.Values) > 0 {
			prompt.WriteString(fmt.Sprintf("- Values: %v\n", user.ContextVault.Values))
		}
		if len(user.ContextVault.Goals) > 0 {
			prompt.WriteString(fmt.Sprintf("- Goals: %v\n", user.ContextVault.Goals))
		}
		if len(plans) > 0 {
			prompt.WriteString(fmt.Sprintf("- Active plans: %d\n", len(plans)))
		}
		prompt.WriteString("\n")
	}

	// Methods/Frameworks
	if len(spec.Methods.Frameworks) > 0 {
		prompt.WriteString("Available frameworks:\n")
		for _, fw := range spec.Methods.Frameworks {
			prompt.WriteString(fmt.Sprintf("- %s: %s\n", fw.Name, fw.Goal))
			if len(fw.Steps) > 0 {
				prompt.WriteString(fmt.Sprintf("  Steps: %v\n", fw.Steps))
			}
		}
		prompt.WriteString("\n")
	}

	// Available tools
	if len(spec.ToolsAllowed.ClientTools) > 0 || len(spec.ToolsAllowed.ServerTools) > 0 {
		prompt.WriteString("Available tools:\n")
		allTools := append(spec.ToolsAllowed.ClientTools, spec.ToolsAllowed.ServerTools...)
		for _, tool := range allTools {
			prompt.WriteString(fmt.Sprintf("- %s\n", tool))
		}
		prompt.WriteString("\n")
	}

	// Safety policies
	prompt.WriteString("Safety policies:\n")
	if spec.Policies.Refusals.Medical {
		prompt.WriteString("- Never give medical advice\n")
	}
	if spec.Policies.Refusals.Legal {
		prompt.WriteString("- Never give legal advice\n")
	}
	if spec.Policies.Safety.NoManipulation {
		prompt.WriteString("- Never manipulate or shame users\n")
	}
	prompt.WriteString("\n")

	// Final instructions
	prompt.WriteString("Respond naturally but follow the style guidelines. Be calm, direct, and actionable.")

	return prompt.String()
}

// parseToolRequests extracts tool requests from the response text
func (ca *CoachAgent) parseToolRequests(text string, spec *models.CoachSpec) []ToolRequest {
	// Simple heuristic-based parsing
	// In production, this would use structured output from Gemini
	requests := []ToolRequest{}

	// Check for calendar mentions
	if strings.Contains(strings.ToLower(text), "calendar") || strings.Contains(strings.ToLower(text), "schedule") {
		if ca.isToolAllowed("calendar_event_create", spec) {
			requests = append(requests, ToolRequest{
				RequestID:            generateRequestID(),
				Tool:                 "calendar_event_create",
				RequiresConfirmation: true,
				Reason:               "Schedule the discussed action",
				Payload:              map[string]interface{}{},
			})
		}
	}

	// Check for reminder mentions
	if strings.Contains(strings.ToLower(text), "remind") {
		if ca.isToolAllowed("reminder_create", spec) {
			requests = append(requests, ToolRequest{
				RequestID:            generateRequestID(),
				Tool:                 "reminder_create",
				RequiresConfirmation: true,
				Reason:               "Create a reminder for this action",
				Payload:              map[string]interface{}{},
			})
		}
	}

	return requests
}

// isToolAllowed checks if a tool is allowed by the CoachSpec
func (ca *CoachAgent) isToolAllowed(tool string, spec *models.CoachSpec) bool {
	allTools := append(spec.ToolsAllowed.ClientTools, spec.ToolsAllowed.ServerTools...)
	for _, t := range allTools {
		if t == tool {
			return true
		}
	}
	return false
}

// Helper functions to generate IDs
func generateSessionID() string {
	return fmt.Sprintf("session_%d", time.Now().UnixNano())
}

func generateMessageID() string {
	return fmt.Sprintf("msg_%d", time.Now().UnixNano())
}

func generateRequestID() string {
	return fmt.Sprintf("tr_%d", time.Now().UnixNano())
}
