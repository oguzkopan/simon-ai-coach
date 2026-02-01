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

// Generate creates a streaming coaching response with conversation history
func (ca *CoachAgent) Generate(
	ctx context.Context,
	userMessage string,
	contextPacket *orchestratorContext.ContextPacket,
	stream chan<- SSEEvent,
) (*CoachOutput, error) {
	// Build system prompt from CoachSpec
	systemPrompt := ca.buildSystemPrompt(contextPacket.CoachSpec, contextPacket.User, contextPacket.ActivePlans)

	// Send stream.open event
	stream <- SSEEvent{
		Type: "stream.open",
		Data: map[string]interface{}{
			"session_id":      generateSessionID(),
			"server_time_iso": time.Now().UTC().Format(time.RFC3339),
		},
	}

	// Convert conversation history to interface{} for Gemini client
	var historyForGemini []interface{}
	for _, msg := range contextPacket.ConversationHistory {
		historyForGemini = append(historyForGemini, map[string]interface{}{
			"role":         msg.Role,
			"content_text": msg.ContentText,
		})
	}

	// Generate streaming response from Gemini WITH conversation history
	fullText := ""
	var tokenChan <-chan string
	var errChan <-chan error
	
	if len(historyForGemini) > 0 {
		// Use history-aware method
		tokenChan, errChan = ca.geminiClient.GenerateContentStreamWithHistory(ctx, systemPrompt, historyForGemini, userMessage)
	} else {
		// First message in conversation - use simple method
		fullPrompt := systemPrompt + "\n\nUser: " + userMessage
		tokenChan, errChan = ca.geminiClient.GenerateContentStream(ctx, fullPrompt)
	}

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

	// Trim trailing whitespace from the final text
	fullText = strings.TrimSpace(fullText)

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
		// Convert formatting rules to natural instructions
		for _, rule := range spec.Style.Formatting.AlwaysEndWith {
			switch rule {
			case "one_question":
				prompt.WriteString("- Always end with one clear question\n")
			case "one_next_action":
				prompt.WriteString("- Always suggest one concrete next action\n")
			case "one_question_one_next_action":
				prompt.WriteString("- Always end with one question and one next action\n")
			default:
				// For other rules, use as-is
				prompt.WriteString(fmt.Sprintf("- Always end with: %s\n", rule))
			}
		}
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
		prompt.WriteString("Available tools (USE THESE to help the user):\n")
		allTools := append(spec.ToolsAllowed.ClientTools, spec.ToolsAllowed.ServerTools...)
		for _, tool := range allTools {
			switch tool {
			case "calendar_event_create":
				prompt.WriteString("- calendar_event_create: Schedule events when user wants to block time\n")
			case "reminder_create":
				prompt.WriteString("- reminder_create: Create reminders for tasks and follow-ups\n")
			case "local_notification_schedule":
				prompt.WriteString("- local_notification_schedule: Schedule notifications for check-ins\n")
			case "plan_create":
				prompt.WriteString("- plan_create: Create structured plans with milestones and actions\n")
			case "memory_write":
				prompt.WriteString("- memory_write: Save important insights and commitments\n")
			case "checkin_schedule":
				prompt.WriteString("- checkin_schedule: Schedule recurring check-ins\n")
			default:
				prompt.WriteString(fmt.Sprintf("- %s\n", tool))
			}
		}
		prompt.WriteString("\nIMPORTANT: When you have enough information, PROACTIVELY offer to use these tools.\n")
		prompt.WriteString("Don't just keep asking questions - take action by creating plans, reminders, or events.\n")
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
	prompt.WriteString("Respond naturally but follow the style guidelines. Be calm, direct, and actionable.\n\n")
	prompt.WriteString("COACHING FLOW:\n")
	prompt.WriteString("1. Review the conversation history to understand context\n")
	prompt.WriteString("2. If you need clarification, ask ONE focused question\n")
	prompt.WriteString("3. Once you understand, suggest a concrete action or create a tool (plan, reminder, event)\n")
	prompt.WriteString("4. Don't endlessly ask questions - move to action after 2-3 exchanges\n")
	prompt.WriteString("5. When creating tools, be specific with details (times, dates, steps)\n")
	prompt.WriteString("6. Remember what the user told you in previous messages - maintain context!\n")

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
