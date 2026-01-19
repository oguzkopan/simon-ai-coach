package agent

import (
	"context"
	"fmt"
	"strings"

	"simon-backend/internal/firestore"
	"simon-backend/internal/models"
)

// ContextBuilder builds context for AI coaching sessions
type ContextBuilder struct {
	firestore *firestore.Client
}

// NewContextBuilder creates a new context builder
func NewContextBuilder(fs *firestore.Client) *ContextBuilder {
	return &ContextBuilder{
		firestore: fs,
	}
}

// CoachingContext represents the full context for a coaching session
type CoachingContext struct {
	UserContext    models.UserContext
	CoachBlueprint map[string]interface{}
	SystemPrompt   string
	IncludeContext bool
}

// Build constructs the coaching context for a session
func (cb *ContextBuilder) Build(ctx context.Context, uid string, coachBlueprint map[string]interface{}) (*CoachingContext, error) {
	// Get user data
	user, err := cb.firestore.GetUser(ctx, uid)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	// Build system prompt
	systemPrompt := cb.buildSystemPrompt(coachBlueprint, user.ContextVault, user.Preferences.IncludeContext)

	return &CoachingContext{
		UserContext:    user.ContextVault,
		CoachBlueprint: coachBlueprint,
		SystemPrompt:   systemPrompt,
		IncludeContext: user.Preferences.IncludeContext,
	}, nil
}

// buildSystemPrompt constructs the system prompt from coach blueprint and user context
func (cb *ContextBuilder) buildSystemPrompt(blueprint map[string]interface{}, userContext models.UserContext, includeContext bool) string {
	var prompt strings.Builder

	// Base coach identity
	prompt.WriteString("You are a minimalist AI coach. Your style:\n")

	// Extract style from blueprint
	if style, ok := blueprint["style"].(map[string]interface{}); ok {
		if tone, ok := style["tone"].(string); ok {
			prompt.WriteString(fmt.Sprintf("- Tone: %s\n", formatTone(tone)))
		}
		if questionStyle, ok := style["question_style"].(string); ok {
			prompt.WriteString(fmt.Sprintf("- Question style: %s\n", formatQuestionStyle(questionStyle)))
		}
	}

	// Extract rules from blueprint
	if rules, ok := blueprint["rules"].(map[string]interface{}); ok {
		prompt.WriteString("\nRules:\n")
		
		if askFirst, ok := rules["alwaysAskOneClarifyingQuestionFirst"].(bool); ok && askFirst {
			prompt.WriteString("- Always ask ONE clarifying question first\n")
		}
		
		if answerShape, ok := rules["defaultAnswerShape"].(string); ok {
			prompt.WriteString(fmt.Sprintf("- Default answer shape: %s\n", formatAnswerShape(answerShape)))
		}
		
		if offerSystem, ok := rules["offerSystemWhenUseful"].(bool); ok && offerSystem {
			prompt.WriteString("- Offer to create a system when useful\n")
		}
		
		if respectContext, ok := rules["respectContextVault"].(bool); ok && respectContext && includeContext {
			prompt.WriteString("- Respect the user's context vault\n")
		}
	}

	// Add user context if enabled
	if includeContext {
		prompt.WriteString("\n")
		prompt.WriteString(cb.formatUserContext(userContext))
	}

	// Extract framework from blueprint
	if framework, ok := blueprint["framework"].(map[string]interface{}); ok {
		if name, ok := framework["name"].(string); ok {
			prompt.WriteString(fmt.Sprintf("\nFramework: %s\n", name))
		}
		
		if steps, ok := framework["steps"].([]interface{}); ok && len(steps) > 0 {
			prompt.WriteString("Steps:\n")
			for i, step := range steps {
				if stepMap, ok := step.(map[string]interface{}); ok {
					if label, ok := stepMap["label"].(string); ok {
						prompt.WriteString(fmt.Sprintf("%d. %s\n", i+1, label))
					}
				}
			}
		}
	}

	// Add safety guidelines
	if safety, ok := blueprint["safety"].(map[string]interface{}); ok {
		prompt.WriteString("\nSafety:\n")
		
		if noMedical, ok := safety["noMedicalLegalClaims"].(bool); ok && noMedical {
			prompt.WriteString("- Never give medical, legal, or financial advice\n")
		}
		
		if encourageHelp, ok := safety["encourageProfessionalHelpWhenNeeded"].(bool); ok && encourageHelp {
			prompt.WriteString("- Suggest professional help when appropriate\n")
		}
	}

	// Final instructions
	prompt.WriteString("\nBe calm, direct, and actionable. Keep responses concise and focused.")

	return prompt.String()
}

// formatUserContext formats the user's context vault for the prompt
func (cb *ContextBuilder) formatUserContext(context models.UserContext) string {
	var parts []string

	if len(context.Values) > 0 {
		parts = append(parts, fmt.Sprintf("User's values: %s", strings.Join(context.Values, ", ")))
	}

	if len(context.Goals) > 0 {
		parts = append(parts, fmt.Sprintf("User's goals: %s", strings.Join(context.Goals, ", ")))
	}

	if len(context.Constraints) > 0 {
		parts = append(parts, fmt.Sprintf("User's constraints: %s", strings.Join(context.Constraints, ", ")))
	}

	if len(context.CurrentProjects) > 0 {
		parts = append(parts, fmt.Sprintf("User's current projects: %s", strings.Join(context.CurrentProjects, ", ")))
	}

	if len(parts) == 0 {
		return ""
	}

	return "User Context:\n" + strings.Join(parts, "\n") + "\n"
}

// Helper functions to format blueprint values

func formatTone(tone string) string {
	switch tone {
	case "calm_direct":
		return "calm and direct"
	case "warm_supportive":
		return "warm and supportive"
	case "socratic":
		return "socratic (ask questions to guide thinking)"
	default:
		return tone
	}
}

func formatQuestionStyle(style string) string {
	switch style {
	case "single_question_first":
		return "ask one clarifying question before giving advice"
	default:
		return style
	}
}

func formatAnswerShape(shape string) string {
	switch shape {
	case "three_steps":
		return "give 3-step answers"
	case "system":
		return "provide a repeatable system"
	case "deep":
		return "provide deep, longform guidance"
	default:
		return shape
	}
}

// BuildForSession builds context for an existing session
func (cb *ContextBuilder) BuildForSession(ctx context.Context, sessionID string) (*CoachingContext, error) {
	// Get session
	session, err := cb.firestore.GetSession(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	// Get coach blueprint
	var blueprint map[string]interface{}
	if session.CoachID != nil {
		coach, err := cb.firestore.GetCoach(ctx, *session.CoachID)
		if err != nil {
			return nil, fmt.Errorf("failed to get coach: %w", err)
		}
		blueprint = coach.Blueprint
	} else {
		// Use default blueprint
		blueprint = getDefaultBlueprint()
	}

	// Build context
	return cb.Build(ctx, session.UID, blueprint)
}

// getDefaultBlueprint returns a default coach blueprint
func getDefaultBlueprint() map[string]interface{} {
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
		"safety": map[string]interface{}{
			"noMedicalLegalClaims":              true,
			"encourageProfessionalHelpWhenNeeded": true,
		},
	}
}
