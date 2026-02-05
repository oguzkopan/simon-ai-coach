package coach

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
	orchestratorContext "simon-backend/internal/orchestrator/context"
	"simon-backend/internal/tools"

	"cloud.google.com/go/firestore"
	"google.golang.org/genai"
)

// CoachOutput represents the output from the coach agent
type CoachOutput struct {
	MessageText    string
	ToolRequests   []ToolRequest
	StructuredData map[string]interface{}
}

// ToolRequest represents a tool execution request
type ToolRequest struct {
	RequestID            string
	Tool                 string
	RequiresConfirmation bool
	Reason               string
	Payload              map[string]interface{}
}

// SSEEvent represents a server-sent event
type SSEEvent struct {
	Type string
	Data map[string]interface{}
}

// CoachAgent generates coaching responses using CoachSpec
type CoachAgent struct {
	geminiClient *gemini.Client
	fs           *firestore.Client
}

// NewCoachAgent creates a new coach agent
func NewCoachAgent(gm *gemini.Client, fs *firestore.Client) *CoachAgent {
	return &CoachAgent{
		geminiClient: gm,
		fs:           fs,
	}
}

// Generate creates a streaming coaching response with conversation history and function calling
func (ca *CoachAgent) Generate(
	ctx context.Context,
	userMessage string,
	attachments []models.Attachment,
	contextPacket *orchestratorContext.ContextPacket,
	stream chan<- SSEEvent,
) (*CoachOutput, error) {
	return ca.GenerateWithAudio(ctx, userMessage, attachments, nil, contextPacket, stream)
}

// GenerateWithAudio creates a streaming coaching response with optional audio input
func (ca *CoachAgent) GenerateWithAudio(
	ctx context.Context,
	userMessage string,
	attachments []models.Attachment,
	audioData []byte,
	contextPacket *orchestratorContext.ContextPacket,
	stream chan<- SSEEvent,
) (*CoachOutput, error) {
	// Build system prompt from CoachSpec
	systemPrompt := ca.buildSystemPrompt(
		contextPacket.CoachSpec,
		contextPacket.User,
		contextPacket.ActivePlans,
		contextPacket.UserContextSummary,
		contextPacket.UserTimezone,
		contextPacket.UserLocalTime,
	)

	// Build tool schemas for function calling
	toolSchemas := ca.buildToolSchemas(contextPacket.CoachSpec)

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

	// Build current message parts
	currentParts := []*genai.Part{}
	
	// Add text message first (required by Gemini)
	if userMessage != "" && userMessage != "🎤 Voice message" {
		currentParts = append(currentParts, &genai.Part{Text: userMessage})
	} else if len(audioData) > 0 {
		// For voice-only messages, add a simple prompt
		currentParts = append(currentParts, &genai.Part{Text: "Listen to this audio and respond naturally."})
	} else {
		currentParts = append(currentParts, &genai.Part{Text: userMessage})
	}
	
	// Add audio after text if available (Gemini requires text first)
	if len(audioData) > 0 {
		log.Printf("🎤 Adding audio to Gemini request: %d bytes, MIME: audio/wav", len(audioData))
		
		// Add WAV header if not already present (check for RIFF signature)
		var audioToSend []byte
		if len(audioData) >= 4 && string(audioData[0:4]) == "RIFF" {
			log.Printf("🎤 Audio already has WAV header")
			audioToSend = audioData
		} else {
			log.Printf("🎤 Audio is raw PCM, adding WAV header")
			audioToSend = addWAVHeaderToAudio(audioData, 16000, 1, 16)
			log.Printf("🎤 WAV header added: %d bytes -> %d bytes", len(audioData), len(audioToSend))
		}
		
		currentParts = append(currentParts, &genai.Part{
			InlineData: &genai.Blob{
				MIMEType: "audio/wav",
				Data:     audioToSend,
			},
		})
	}
	
	// Add other attachments
	for _, att := range attachments {
		if att.Type == "image" || att.Type == "file" {
			fileURI := att.StoragePath
			mimeType := att.MimeType
			if mimeType == "" {
				if att.Type == "image" {
					mimeType = "image/jpeg"
				} else {
					mimeType = "application/pdf"
				}
			}

			currentParts = append(currentParts, &genai.Part{
				FileData: &genai.FileData{
					MIMEType: mimeType,
					FileURI:  fileURI,
				},
			})
		}
	}

	// Generate streaming response from Gemini WITH function calling
	fullText := ""
	toolRequests := []ToolRequest{}

	if len(toolSchemas) > 0 {
		// Use function calling version
		resultChan, errChan := ca.geminiClient.GenerateContentStreamWithTools(
			ctx, systemPrompt, historyForGemini, currentParts, toolSchemas,
		)

		// Stream results (text and tool calls)
		for {
			select {
			case result, ok := <-resultChan:
				if !ok {
					// Stream finished
					goto streamDone
				}

				if result.IsToolCall {
					// Gemini wants to call a tool
					fmt.Printf("🔧 Tool call detected: %s with args: %+v\n", result.ToolCall.Name, result.ToolCall.Arguments)

					// Transform Gemini function call format to tool registry format
					transformedPayload := ca.transformToolPayload(result.ToolCall.Name, result.ToolCall.Arguments)

					// Check if this is a server tool that should be executed immediately
					if ca.isServerTool(result.ToolCall.Name) {
						fmt.Printf("🔧 Server tool detected, executing immediately: %s\n", result.ToolCall.Name)

						// Execute server tool immediately
						output, err := ca.executeServerTool(ctx, result.ToolCall.Name, transformedPayload, contextPacket)
						if err != nil {
							fmt.Printf("❌ Server tool execution failed: %v\n", err)
							// Send error event
							stream <- SSEEvent{
								Type: "tool.status",
								Data: map[string]interface{}{
									"request_id": generateRequestID(),
									"tool_id":    result.ToolCall.Name,
									"status":     "failed",
									"error":      err.Error(),
								},
							}
						} else {
							fmt.Printf("✅ Server tool executed successfully: %+v\n", output)
							// Send success event
							stream <- SSEEvent{
								Type: "tool.status",
								Data: map[string]interface{}{
									"request_id": generateRequestID(),
									"tool_id":    result.ToolCall.Name,
									"status":     "executed",
									"output":     output,
								},
							}
						}
					} else {
						// Client tool - send request for user confirmation
						toolReq := ToolRequest{
							RequestID:            generateRequestID(),
							Tool:                 result.ToolCall.Name,
							RequiresConfirmation: ca.requiresConfirmation(result.ToolCall.Name, contextPacket.CoachSpec),
							Reason:               fmt.Sprintf("Execute %s", result.ToolCall.Name),
							Payload:              transformedPayload,
						}
						toolRequests = append(toolRequests, toolReq)

						// Send tool request event
						stream <- SSEEvent{
							Type: "tool.request",
							Data: map[string]interface{}{
								"request_id":            toolReq.RequestID,
								"tool_id":               toolReq.Tool,
								"input":                 transformedPayload,
								"requires_confirmation": toolReq.RequiresConfirmation,
								"reason":                toolReq.Reason,
							},
						}
					}
				} else {
					// Regular text response
					fullText += result.Text
					stream <- SSEEvent{
						Type: "message.delta",
						Data: map[string]interface{}{
							"role":  "assistant",
							"delta": result.Text,
						},
					}
				}

			case err := <-errChan:
				if err != nil {
					// Check if it's a quota error
					errMsg := err.Error()
					if strings.Contains(errMsg, "RESOURCE_EXHAUSTED") || strings.Contains(errMsg, "429") {
						return nil, fmt.Errorf("API rate limit reached. Please wait a moment and try again")
					}
					return nil, fmt.Errorf("gemini stream failed: %w", err)
				}
			}
		}
	} else {
		// No tools available, use regular streaming
		var tokenChan <-chan string
		var errChan <-chan error

		if len(historyForGemini) > 0 || len(attachments) > 0 {
			tokenChan, errChan = ca.geminiClient.GenerateContentStreamWithHistory(ctx, systemPrompt, historyForGemini, currentParts)
		} else {
			fullPrompt := systemPrompt + "\n\nUser: " + userMessage
			tokenChan, errChan = ca.geminiClient.GenerateContentStream(ctx, fullPrompt)
		}

		// Stream tokens
		for {
			select {
			case token, ok := <-tokenChan:
				if !ok {
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
					// Check if it's a quota error
					errMsg := err.Error()
					if strings.Contains(errMsg, "RESOURCE_EXHAUSTED") || strings.Contains(errMsg, "429") {
						return nil, fmt.Errorf("API rate limit reached. Please wait a moment and try again")
					}
					return nil, fmt.Errorf("gemini stream failed: %w", err)
				}
			}
		}
	}

streamDone:

	// Trim trailing whitespace from the final text
	fullText = strings.TrimSpace(fullText)

	// Send message.final event (even if empty when only tool calls)
	stream <- SSEEvent{
		Type: "message.final",
		Data: map[string]interface{}{
			"message_id":   generateMessageID(),
			"role":         "assistant",
			"text":         fullText,
			"render_hints": map[string]interface{}{"max_cards": 3},
		},
	}

	return &CoachOutput{
		MessageText:  fullText,
		ToolRequests: toolRequests,
	}, nil
}

// requiresConfirmation checks if a tool requires user confirmation
func (ca *CoachAgent) requiresConfirmation(tool string, spec *models.CoachSpec) bool {
	for _, t := range spec.ToolsAllowed.RequiresUserConfirmation {
		if t == tool {
			return true
		}
	}
	return false
}

// buildSystemPrompt constructs the system prompt from CoachSpec
func (ca *CoachAgent) buildSystemPrompt(
	spec *models.CoachSpec,
	user *models.User,
	plans []models.Plan,
	userContextSummary string,
	userTimezone string,
	userLocalTime string,
) string {
	var prompt strings.Builder

	// CRITICAL: Current date/time context - USE USER'S TIMEZONE
	now := time.Now()
	
	// Parse user's local time if provided
	var userTime time.Time
	var userLoc *time.Location
	if userLocalTime != "" && userTimezone != "" {
		// Parse user's timezone
		loc, err := time.LoadLocation(userTimezone)
		if err == nil {
			userLoc = loc
			// Parse user's local time
			parsedTime, err := time.Parse(time.RFC3339, userLocalTime)
			if err == nil {
				userTime = parsedTime
			} else {
				// Fallback to server time in user's timezone
				userTime = now.In(loc)
			}
		} else {
			// Fallback to UTC if timezone is invalid
			userTime = now.UTC()
			userLoc = time.UTC
		}
	} else {
		// Fallback to UTC if no timezone provided
		userTime = now.UTC()
		userLoc = time.UTC
	}
	
	// Display user's local time prominently
	prompt.WriteString("═══════════════════════════════════════════════════════════\n")
	prompt.WriteString("USER'S CURRENT DATE AND TIME (THIS IS CRITICAL!):\n")
	prompt.WriteString(fmt.Sprintf("Local Time: %s\n", userTime.Format("Monday, January 2, 2006 at 3:04 PM MST")))
	prompt.WriteString(fmt.Sprintf("ISO Format: %s\n", userTime.Format(time.RFC3339)))
	prompt.WriteString(fmt.Sprintf("Timezone: %s\n", userTimezone))
	prompt.WriteString(fmt.Sprintf("Day of Week: %s\n", userTime.Format("Monday")))
	prompt.WriteString("═══════════════════════════════════════════════════════════\n\n")
	
	prompt.WriteString("CRITICAL INSTRUCTIONS FOR TIME-BASED ACTIONS:\n")
	prompt.WriteString("1. The time above is the USER'S LOCAL TIME - use this as your reference!\n")
	prompt.WriteString("2. When user says 'tomorrow at 9am', calculate based on THEIR timezone\n")
	prompt.WriteString("3. Always use ISO 8601 format with timezone: YYYY-MM-DDTHH:MM:SS+HH:MM\n")
	prompt.WriteString(fmt.Sprintf("4. Example: If user says 'tomorrow at 9am' and today is %s,\n", userTime.Format("2006-01-02")))
	
	// Calculate tomorrow at 9am in user's timezone
	tomorrow := userTime.AddDate(0, 0, 1)
	tomorrowAt9 := time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(), 9, 0, 0, 0, userLoc)
	prompt.WriteString(fmt.Sprintf("   use: %s\n", tomorrowAt9.Format(time.RFC3339)))
	prompt.WriteString("5. NEVER use UTC times - always use the user's timezone!\n")
	prompt.WriteString("6. When creating events/reminders, the times MUST match what the user expects in THEIR timezone\n\n")

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

	// User context summary (if enabled by user)
	if userContextSummary != "" {
		prompt.WriteString(userContextSummary)
		prompt.WriteString("\n")
	} else if user != nil {
		// Fallback to basic context if no summary provided
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
		prompt.WriteString("\nIMPORTANT: You have access to function calling. When you have enough information:\n")
		prompt.WriteString("1. CALL THE FUNCTION directly - don't just say you'll do it\n")
		prompt.WriteString("2. Use the actual function call mechanism, not text descriptions\n")
		prompt.WriteString("3. After 2-3 exchanges, move from questions to ACTION by calling functions\n")
		prompt.WriteString("4. Be specific with times, dates, and details in function arguments\n")
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

// buildToolSchemas creates Gemini function declarations for allowed tools
func (ca *CoachAgent) buildToolSchemas(spec *models.CoachSpec) []*genai.Tool {
	declarations := []*genai.FunctionDeclaration{}

	// Calendar Event Create
	if ca.isToolAllowed("calendar_event_create", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "calendar_event_create",
			Description: "Create a calendar event to block time for an activity. Use this when the user wants to schedule time for work, meetings, or activities.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"title": {
						Type:        genai.TypeString,
						Description: "Event title (e.g., 'Deep Work Session', 'Team Meeting')",
					},
					"start_iso": {
						Type:        genai.TypeString,
						Description: "Start time in ISO 8601 format (e.g., '2024-02-01T09:00:00Z')",
					},
					"end_iso": {
						Type:        genai.TypeString,
						Description: "End time in ISO 8601 format (e.g., '2024-02-01T11:00:00Z')",
					},
					"location": {
						Type:        genai.TypeString,
						Description: "Optional location (e.g., 'Home Office', 'Conference Room A')",
					},
					"notes": {
						Type:        genai.TypeString,
						Description: "Optional notes or description",
					},
				},
				Required: []string{"title", "start_iso", "end_iso"},
			},
		})
	}

	// Reminder Create
	if ca.isToolAllowed("reminder_create", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "reminder_create",
			Description: "Create a reminder for a task or follow-up. Use this when the user wants to be reminded about something.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"title": {
						Type:        genai.TypeString,
						Description: "Reminder title (e.g., 'Call John', 'Submit report')",
					},
					"due_iso": {
						Type:        genai.TypeString,
						Description: "Optional due date/time in ISO 8601 format (e.g., '2024-02-01T15:00:00Z')",
					},
					"notes": {
						Type:        genai.TypeString,
						Description: "Optional notes or details",
					},
					"priority": {
						Type:        genai.TypeInteger,
						Description: "Priority level 0-9 (0=none, 5=medium, 9=high)",
					},
				},
				Required: []string{"title"},
			},
		})
	}

	// Local Notification Schedule
	if ca.isToolAllowed("local_notification_schedule", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "local_notification_schedule",
			Description: "Schedule a local push notification for check-ins or nudges. Use this for recurring reminders or coaching check-ins.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"title": {
						Type:        genai.TypeString,
						Description: "Notification title",
					},
					"body": {
						Type:        genai.TypeString,
						Description: "Notification body text",
					},
					"fire_at_iso": {
						Type:        genai.TypeString,
						Description: "When to fire the notification in ISO 8601 format",
					},
				},
				Required: []string{"title", "body", "fire_at_iso"},
			},
		})
	}

	// Plan Create
	if ca.isToolAllowed("plan_create", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "plan_create",
			Description: "Create a structured plan with milestones and next actions. Use this when the user wants to plan a project, goal, or initiative.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"title": {
						Type:        genai.TypeString,
						Description: "Plan title (e.g., 'Launch Side Project', 'Fitness Plan')",
					},
					"objective": {
						Type:        genai.TypeString,
						Description: "What the plan aims to achieve",
					},
					"horizon": {
						Type:        genai.TypeString,
						Description: "Time horizon for the plan",
						Enum:        []string{"today", "week", "month", "quarter"},
					},
					"milestones": {
						Type:        genai.TypeArray,
						Description: "Key milestones (max 8)",
						Items: &genai.Schema{
							Type: genai.TypeObject,
							Properties: map[string]*genai.Schema{
								"title":       {Type: genai.TypeString, Description: "Milestone title"},
								"description": {Type: genai.TypeString, Description: "What success looks like"},
							},
						},
					},
					"next_actions": {
						Type:        genai.TypeArray,
						Description: "Concrete next actions (max 12)",
						Items: &genai.Schema{
							Type: genai.TypeObject,
							Properties: map[string]*genai.Schema{
								"title":        {Type: genai.TypeString, Description: "Action title"},
								"duration_min": {Type: genai.TypeInteger, Description: "Estimated duration in minutes"},
							},
						},
					},
				},
				Required: []string{"title", "objective", "horizon"},
			},
		})
	}

	// Memory Write
	if ca.isToolAllowed("memory_write", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "memory_write",
			Description: "Save important user preferences, commitments, or insights to long-term memory. Use this to remember things about the user.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"commitments": {
						Type:        genai.TypeArray,
						Description: "User commitments or promises",
						Items: &genai.Schema{
							Type:        genai.TypeString,
							Description: "A specific commitment (e.g., 'Write 500 words daily')",
						},
					},
					"preferences": {
						Type:        genai.TypeObject,
						Description: "User preferences as key-value pairs",
					},
				},
			},
		})
	}

	// Check-in Schedule
	if ca.isToolAllowed("checkin_schedule", spec) {
		declarations = append(declarations, &genai.FunctionDeclaration{
			Name:        "checkin_schedule",
			Description: "Schedule recurring check-ins with the user. Use this for daily, weekly, or custom recurring coaching sessions.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"cadence_kind": {
						Type:        genai.TypeString,
						Description: "Frequency of check-ins",
						Enum:        []string{"daily", "weekdays", "weekly"},
					},
					"hour": {
						Type:        genai.TypeInteger,
						Description: "Hour of day (0-23) for check-in",
					},
					"minute": {
						Type:        genai.TypeInteger,
						Description: "Minute of hour (0-59) for check-in",
					},
				},
				Required: []string{"cadence_kind", "hour", "minute"},
			},
		})
	}

	// Build final tool set
	var tools []*genai.Tool

	// Add function declarations if any
	if len(declarations) > 0 {
		tools = append(tools, &genai.Tool{FunctionDeclarations: declarations})
	}

	// ALWAYS add Google Search grounding
	tools = append(tools, &genai.Tool{GoogleSearch: &genai.GoogleSearch{}})

	return tools
}

// transformToolPayload transforms Gemini function call format to tool registry format
func (ca *CoachAgent) transformToolPayload(toolName string, geminiPayload map[string]interface{}) map[string]interface{} {
	switch toolName {
	case "local_notification_schedule":
		// Gemini sends: {title, body, fire_at_iso}
		// Tool registry expects: {title, body, trigger: {kind, fire_at_iso}, idempotency_key}
		transformed := make(map[string]interface{})

		// Copy direct fields
		if title, ok := geminiPayload["title"]; ok {
			transformed["title"] = title
		}
		if body, ok := geminiPayload["body"]; ok {
			transformed["body"] = body
		}

		// Transform fire_at_iso to trigger object
		if fireAtISO, ok := geminiPayload["fire_at_iso"]; ok {
			transformed["trigger"] = map[string]interface{}{
				"kind":        "at_datetime",
				"fire_at_iso": fireAtISO,
			}
		}

		// Generate idempotency key
		transformed["idempotency_key"] = fmt.Sprintf("notif_%d", time.Now().UnixNano())

		return transformed

	case "calendar_event_create":
		// Gemini sends: {title, start_iso, end_iso, location?, notes?}
		// Tool registry expects: same + idempotency_key
		transformed := make(map[string]interface{})

		// Copy all fields
		for k, v := range geminiPayload {
			transformed[k] = v
		}

		// Generate idempotency key
		transformed["idempotency_key"] = fmt.Sprintf("cal_%d", time.Now().UnixNano())

		return transformed

	case "reminder_create":
		// Gemini sends: {title, due_iso?, notes?, priority?}
		// Tool registry expects: same + idempotency_key
		transformed := make(map[string]interface{})

		// Copy all fields
		for k, v := range geminiPayload {
			transformed[k] = v
		}

		// Generate idempotency key
		transformed["idempotency_key"] = fmt.Sprintf("rem_%d", time.Now().UnixNano())

		return transformed

	default:
		// For other tools, return as-is
		return geminiPayload
	}
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

// isServerTool checks if a tool is executed on the server
func (ca *CoachAgent) isServerTool(toolName string) bool {
	serverTools := map[string]bool{
		"memory_read":      true,
		"memory_write":     true,
		"plan_create":      true,
		"plan_update":      true,
		"plan_list_active": true,
		"checkin_schedule": true,
	}
	return serverTools[toolName]
}

// executeServerTool executes a server-side tool
func (ca *CoachAgent) executeServerTool(ctx context.Context, toolName string, payload map[string]interface{}, contextPacket *orchestratorContext.ContextPacket) (map[string]interface{}, error) {
	// Import the tools package
	planService := tools.NewPlanService(ca.fs)
	memoryService := tools.NewMemoryService(ca.fs)
	checkinService := tools.NewCheckinService(ca.fs)

	// Get UID from context
	uid := ""
	if contextPacket.User != nil {
		uid = contextPacket.User.UID
	}

	// Get CoachID from context
	coachID := contextPacket.CoachID

	switch toolName {
	case "memory_read":
		query, _ := payload["query"].(string)
		limit, _ := payload["limit"].(float64)

		req := tools.MemoryReadRequest{
			UID:   uid,
			Query: query,
			Limit: int(limit),
		}

		resp, err := memoryService.Read(ctx, req)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{
			"hits": resp.Hits,
		}, nil

	case "memory_write":
		patchData, _ := payload["patch"].(map[string]interface{})

		var patch tools.MemoryPatch
		if patchJSON, err := json.Marshal(patchData); err == nil {
			json.Unmarshal(patchJSON, &patch)
		}

		req := tools.MemoryWriteRequest{
			UID:   uid,
			Patch: patch,
		}

		if err := memoryService.Write(ctx, req); err != nil {
			return nil, err
		}

		return map[string]interface{}{"status": "written"}, nil

	case "plan_create":
		// Build plan from payload
		var plan models.Plan
		if planJSON, err := json.Marshal(payload); err == nil {
			json.Unmarshal(planJSON, &plan)
		}

		req := tools.PlanCreateRequest{
			UID:     uid,
			CoachID: coachID,
			Plan:    plan,
		}

		resp, err := planService.Create(ctx, req)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{
			"plan_id": resp.PlanID,
			"status":  resp.Status,
		}, nil

	case "plan_update":
		planID, _ := payload["plan_id"].(string)
		updates, _ := payload["updates"].(map[string]interface{})

		req := tools.PlanUpdateRequest{
			UID:     uid,
			PlanID:  planID,
			Updates: updates,
		}

		resp, err := planService.Update(ctx, req)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{"status": resp.Status}, nil

	case "plan_list_active":
		limit, _ := payload["limit"].(float64)

		req := tools.PlanListRequest{
			UID:   uid,
			Limit: int(limit),
		}

		resp, err := planService.ListActive(ctx, req)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{"plans": resp.Plans}, nil

	case "checkin_schedule":
		channel, _ := payload["channel"].(string)
		cadenceData, _ := payload["cadence"].(map[string]interface{})

		var cadence models.CheckinCadence
		if cadenceJSON, err := json.Marshal(cadenceData); err == nil {
			json.Unmarshal(cadenceJSON, &cadence)
		}

		req := tools.CheckinScheduleRequest{
			UID:     uid,
			CoachID: coachID,
			Cadence: cadence,
			Channel: channel,
		}

		resp, err := checkinService.Schedule(ctx, req)
		if err != nil {
			return nil, err
		}

		return map[string]interface{}{
			"checkin_id": resp.CheckinID,
			"status":     resp.Status,
		}, nil

	default:
		return nil, fmt.Errorf("unknown server tool: %s", toolName)
	}
}

// addWAVHeaderToAudio adds a WAV file header to raw PCM data
func addWAVHeaderToAudio(pcmData []byte, sampleRate, channels, bitsPerSample int) []byte {
	dataSize := len(pcmData)
	byteRate := sampleRate * channels * bitsPerSample / 8
	blockAlign := channels * bitsPerSample / 8
	
	header := make([]byte, 44)
	
	// RIFF header
	copy(header[0:4], "RIFF")
	binary.LittleEndian.PutUint32(header[4:8], uint32(36+dataSize))
	copy(header[8:12], "WAVE")
	
	// fmt chunk
	copy(header[12:16], "fmt ")
	binary.LittleEndian.PutUint32(header[16:20], 16) // fmt chunk size
	binary.LittleEndian.PutUint16(header[20:22], 1)  // audio format (1 = PCM)
	binary.LittleEndian.PutUint16(header[22:24], uint16(channels))
	binary.LittleEndian.PutUint32(header[24:28], uint32(sampleRate))
	binary.LittleEndian.PutUint32(header[28:32], uint32(byteRate))
	binary.LittleEndian.PutUint16(header[32:34], uint16(blockAlign))
	binary.LittleEndian.PutUint16(header[34:36], uint16(bitsPerSample))
	
	// data chunk
	copy(header[36:40], "data")
	binary.LittleEndian.PutUint32(header[40:44], uint32(dataSize))
	
	// Combine header and data
	wavData := append(header, pcmData...)
	return wavData
}
