package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"google.golang.org/genai"
	"simon-backend/internal/gemini"
	"simon-backend/internal/models"
)

// CoachSpecBuilder builds a complete CoachSpec from user inputs
type CoachSpecBuilder struct {
	specialty     string
	style         string
	tone          string
	verbosity     string
	customPrompt  string
	audience      []string
	samplePrompts []string
	geminiClient  *gemini.Client
	useLLM        bool
}

// NewCoachSpecBuilder creates a new CoachSpec builder
func NewCoachSpecBuilder() *CoachSpecBuilder {
	return &CoachSpecBuilder{
		audience: []string{"professionals", "individuals"},
		useLLM:   false, // Default to template-based
	}
}

// WithGeminiClient enables LLM-powered generation
func (b *CoachSpecBuilder) WithGeminiClient(client *gemini.Client) *CoachSpecBuilder {
	b.geminiClient = client
	b.useLLM = true
	return b
}

// WithSpecialty sets the coach specialty
func (b *CoachSpecBuilder) WithSpecialty(specialty string) *CoachSpecBuilder {
	b.specialty = strings.ToLower(specialty)
	return b
}

// WithStyle sets the coaching style
func (b *CoachSpecBuilder) WithStyle(style string) *CoachSpecBuilder {
	b.style = strings.ToLower(style)
	return b
}

// WithTone sets the tone (gentle, balanced, intense)
func (b *CoachSpecBuilder) WithTone(tone string) *CoachSpecBuilder {
	b.tone = tone
	return b
}

// WithVerbosity sets the verbosity level
func (b *CoachSpecBuilder) WithVerbosity(verbosity string) *CoachSpecBuilder {
	b.verbosity = verbosity
	return b
}

// WithCustomPrompt adds a custom system prompt
func (b *CoachSpecBuilder) WithCustomPrompt(prompt string) *CoachSpecBuilder {
	b.customPrompt = prompt
	return b
}

// WithAudience sets the target audience
func (b *CoachSpecBuilder) WithAudience(audience []string) *CoachSpecBuilder {
	b.audience = audience
	return b
}

// WithSamplePrompts sets custom sample prompts
func (b *CoachSpecBuilder) WithSamplePrompts(prompts []string) *CoachSpecBuilder {
	b.samplePrompts = prompts
	return b
}

// Build creates a complete CoachSpec
func (b *CoachSpecBuilder) Build(name, tagline string) *models.CoachSpec {
	// Set defaults
	if b.tone == "" {
		b.tone = "balanced"
	}
	if b.verbosity == "" {
		b.verbosity = "medium"
	}
	if b.style == "" {
		b.style = "direct"
	}

	// Use LLM-powered generation if available
	if b.useLLM && b.geminiClient != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		
		spec, err := b.buildWithLLM(ctx, name, tagline)
		if err != nil {
			log.Printf("LLM generation failed, falling back to template: %v", err)
			// Fall through to template-based generation
		} else {
			return spec
		}
	}

	// Template-based generation (fallback or default)
	spec := &models.CoachSpec{
		Version:      "1.0",
		Identity:     b.buildIdentity(name, tagline),
		Style:        b.buildStyle(),
		Methods:      b.buildMethods(),
		Policies:     b.buildPolicies(),
		ToolsAllowed: b.buildToolsAllowed(),
		Outputs:      b.buildOutputs(),
	}

	return spec
}

// buildWithLLM uses Gemini to generate a rich, comprehensive CoachSpec with structured output
func (b *CoachSpecBuilder) buildWithLLM(ctx context.Context, name, tagline string) (*models.CoachSpec, error) {
	prompt := b.buildLLMPrompt(name, tagline)
	
	log.Printf("Generating CoachSpec with LLM for: %s (specialty: %s, style: %s)", name, b.specialty, b.style)
	
	// Define the schema for structured output
	schema := b.buildCoachSpecSchema()
	
	// Use structured output generation
	temperature := float32(0.8)
	config := &genai.GenerateContentConfig{
		Temperature:      &temperature,
		MaxOutputTokens:  8192,
		ResponseMIMEType: "application/json",
		ResponseSchema:   schema,
		ThinkingConfig: &genai.ThinkingConfig{
			ThinkingLevel: genai.ThinkingLevelMedium,
		},
	}
	
	result, err := b.geminiClient.Raw.Models.GenerateContent(ctx, b.geminiClient.Model, genai.Text(prompt), config)
	if err != nil {
		return nil, fmt.Errorf("LLM generation failed: %w", err)
	}
	
	// Extract JSON from response
	var jsonText string
	for _, candidate := range result.Candidates {
		if candidate.Content != nil {
			for _, part := range candidate.Content.Parts {
				if part.Text != "" {
					jsonText += part.Text
				}
			}
		}
	}
	
	if jsonText == "" {
		return nil, fmt.Errorf("no content generated")
	}
	
	log.Printf("LLM generated %d characters of structured JSON", len(jsonText))
	
	// Parse the JSON into CoachSpec - should be clean JSON now
	var spec models.CoachSpec
	if err := json.Unmarshal([]byte(jsonText), &spec); err != nil {
		log.Printf("Failed to parse LLM output. First 500 chars: %s", jsonText[:min(500, len(jsonText))])
		return nil, fmt.Errorf("failed to parse LLM output: %w", err)
	}
	
	// Ensure required fields are set
	spec.Version = "1.0"
	
	// Ensure policies are set with safe defaults
	if spec.Policies.Refusals.Medical == false && spec.Policies.Refusals.Legal == false {
		spec.Policies = b.buildPolicies()
	}
	
	// Always set tools and outputs from template (too complex for LLM)
	spec.ToolsAllowed = b.buildToolsAllowed()
	spec.Outputs = b.buildOutputs()
	
	log.Printf("Successfully generated CoachSpec with LLM: %d problem statements, %d outcomes, %d sample prompts, %d frameworks",
		len(spec.Identity.ProblemStatements),
		len(spec.Identity.Outcomes),
		len(spec.Identity.SamplePrompts),
		len(spec.Methods.Frameworks))
	
	return &spec, nil
}

// buildCoachSpecSchema creates the OpenAPI 3.0 schema for structured output
func (b *CoachSpecBuilder) buildCoachSpecSchema() *genai.Schema {
	return &genai.Schema{
		Type: genai.TypeObject,
		Properties: map[string]*genai.Schema{
			"version": {
				Type:        genai.TypeString,
				Description: "CoachSpec version",
			},
			"identity": {
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"name": {
						Type:        genai.TypeString,
						Description: "Coach name",
					},
					"tagline": {
						Type:        genai.TypeString,
						Description: "Coach tagline/promise",
					},
					"niche": {
						Type:        genai.TypeString,
						Description: "Coach specialty/niche",
					},
					"audience": {
						Type:        genai.TypeArray,
						Description: "Target audience segments (3-5 specific groups)",
						Items: &genai.Schema{
							Type: genai.TypeString,
						},
					},
					"problemStatements": {
						Type:        genai.TypeArray,
						Description: "Specific problems this coach addresses (5-8 diverse statements)",
						Items: &genai.Schema{
							Type: genai.TypeString,
						},
					},
					"outcomes": {
						Type:        genai.TypeArray,
						Description: "Concrete, measurable outcomes users can achieve (5-8 outcomes)",
						Items: &genai.Schema{
							Type: genai.TypeString,
						},
					},
					"persona": {
						Type: genai.TypeObject,
						Properties: map[string]*genai.Schema{
							"archetype": {
								Type:        genai.TypeString,
								Description: "Coach archetype: mentor, strategist, philosopher, analyst, champion, or practitioner",
								Enum:        []string{"mentor", "strategist", "philosopher", "analyst", "champion", "practitioner"},
							},
							"voice": {
								Type:        genai.TypeString,
								Description: "Detailed voice description capturing personality and approach (2-3 sentences)",
							},
							"boundaries": {
								Type:        genai.TypeArray,
								Description: "Professional boundaries",
								Items: &genai.Schema{
									Type: genai.TypeString,
								},
							},
						},
						Required: []string{"archetype", "voice", "boundaries"},
					},
					"samplePrompts": {
						Type:        genai.TypeArray,
						Description: "Natural, engaging sample prompts that showcase capabilities (5-10 prompts)",
						Items: &genai.Schema{
							Type: genai.TypeString,
						},
					},
				},
				Required: []string{"name", "tagline", "niche", "audience", "problemStatements", "outcomes", "persona", "samplePrompts"},
			},
			"style": {
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"tone": {
						Type:        genai.TypeString,
						Description: "Communication tone",
					},
					"verbosity": {
						Type:        genai.TypeString,
						Description: "Response length preference: low, medium, or high",
						Enum:        []string{"low", "medium", "high"},
					},
					"formatting": {
						Type: genai.TypeObject,
						Properties: map[string]*genai.Schema{
							"maxBullets": {
								Type:        genai.TypeInteger,
								Description: "Maximum bullet points per response",
							},
							"maxSentencesPerParagraph": {
								Type:        genai.TypeInteger,
								Description: "Maximum sentences per paragraph",
							},
							"alwaysEndWith": {
								Type:        genai.TypeArray,
								Description: "Phrases to end responses with",
								Items: &genai.Schema{
									Type: genai.TypeString,
								},
							},
							"useEmoji": {
								Type:        genai.TypeString,
								Description: "Emoji usage: never, sparingly, or frequently",
								Enum:        []string{"never", "sparingly", "frequently"},
							},
							"allowedMarkdown": {
								Type:        genai.TypeArray,
								Description: "Allowed markdown elements: bullet_list, numbered_list, bold, italic, code, heading",
								Items: &genai.Schema{
									Type: genai.TypeString,
									Enum: []string{"bullet_list", "numbered_list", "bold", "italic", "code", "heading"},
								},
							},
						},
					},
					"interactionRules": {
						Type: genai.TypeObject,
						Properties: map[string]*genai.Schema{
							"askOneQuestionAtATime": {
								Type:        genai.TypeBoolean,
								Description: "Whether to ask one question at a time",
							},
							"confirmBeforeScheduling": {
								Type:        genai.TypeBoolean,
								Description: "Whether to confirm before scheduling",
							},
							"avoidMotivationalFluff": {
								Type:        genai.TypeBoolean,
								Description: "Whether to avoid motivational language",
							},
							"reflectUserLanguage": {
								Type:        genai.TypeBoolean,
								Description: "Whether to mirror user's language style",
							},
						},
					},
				},
				Required: []string{"tone", "verbosity", "formatting", "interactionRules"},
			},
			"methods": {
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"frameworks": {
						Type:        genai.TypeArray,
						Description: "Coaching frameworks with detailed steps (2-4 relevant frameworks)",
						Items: &genai.Schema{
							Type: genai.TypeObject,
							Properties: map[string]*genai.Schema{
								"id": {
									Type:        genai.TypeString,
									Description: "Framework identifier",
								},
								"name": {
									Type:        genai.TypeString,
									Description: "Framework name",
								},
								"goal": {
									Type:        genai.TypeString,
									Description: "What this framework achieves",
								},
								"steps": {
									Type:        genai.TypeArray,
									Description: "Step-by-step process",
									Items: &genai.Schema{
										Type: genai.TypeString,
									},
								},
								"whenToUse": {
									Type:        genai.TypeArray,
									Description: "Situations when to use this framework",
									Items: &genai.Schema{
										Type: genai.TypeString,
									},
								},
							},
							Required: []string{"id", "name", "goal", "steps", "whenToUse"},
						},
					},
					"defaultProtocols": {
						Type: genai.TypeObject,
						Properties: map[string]*genai.Schema{
							"quickNudge": {
								Type: genai.TypeObject,
								Properties: map[string]*genai.Schema{
									"template": {
										Type:        genai.TypeArray,
										Description: "Quick nudge template steps",
										Items: &genai.Schema{
											Type: genai.TypeString,
										},
									},
								},
							},
							"deepSession": {
								Type: genai.TypeObject,
								Properties: map[string]*genai.Schema{
									"phases": {
										Type:        genai.TypeArray,
										Description: "Deep session phases",
										Items: &genai.Schema{
											Type: genai.TypeString,
										},
									},
								},
							},
						},
					},
				},
			},
		},
		Required: []string{"version", "identity", "style", "methods"},
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// buildLLMPrompt creates a detailed prompt for Gemini to generate the CoachSpec
func (b *CoachSpecBuilder) buildLLMPrompt(name, tagline string) string {
	return fmt.Sprintf(`You are an expert AI coach designer. Generate a comprehensive, production-ready coaching specification for a new AI coaching assistant.

**Coach Details:**
- Name: %s
- Tagline: %s
- Specialty: %s
- Style: %s
- Tone: %s
- Verbosity: %s
%s

**Your Task:**
Create a RICH, DETAILED, PROFESSIONAL coach specification that goes far beyond basic templates. This will be used in production, so make it exceptional and specific to the specialty "%s".

**Requirements:**

1. **Problem Statements** (7-10 diverse, specific statements):
   - Be VERY specific and relatable to the specialty
   - Address real, concrete pain points users face
   - Make them conversational and authentic
   - Cover different aspects of the specialty
   - Examples: "I'm stuck on a project and don't know where to start", "I keep second-guessing my decisions"

2. **Outcomes** (7-10 concrete, measurable outcomes):
   - Make them specific and achievable
   - Directly related to the specialty
   - Inspiring but realistic
   - Varied in scope (immediate to long-term)
   - Examples: "Clear next action within 5 minutes", "Reduced decision paralysis"

3. **Sample Prompts** (7-12 engaging, natural prompts):
   - Sound like REAL user questions
   - Showcase different use cases and depths
   - Vary in complexity (quick nudges to deep sessions)
   - Make users excited to try them
   - Examples: "Help me break through this creative block", "I need to make a tough decision about my career"

4. **Frameworks** (2-4 relevant, actionable frameworks):
   - ONLY include if highly relevant to the specialty
   - Provide practical, step-by-step guidance
   - Include clear "when to use" scenarios
   - Make them specialty-specific and unique
   - Each framework should have 3-6 concrete steps

5. **Voice Description** (2-3 compelling sentences):
   - Capture the unique personality and approach
   - Reflect the style (%s) and tone (%s)
   - Be distinctive and memorable
   - Include the tagline naturally: "%s"
   - Make it feel like a real coach's voice

6. **Audience** (3-5 specific segments):
   - Be SPECIFIC, not generic
   - Tailor precisely to the specialty
   - Examples: "startup_founders", "creative_professionals", "students_preparing_for_exams"

7. **Persona Archetype**:
   - Choose the BEST fit for this specialty and style
   - Options: mentor, strategist, philosopher, analyst, champion, practitioner
   - Consider: %s style with %s tone

**Quality Standards:**
- Avoid ALL generic language - be specific to "%s"
- Make everything feel authentic, useful, and professional
- Consider the coaching style throughout
- Ensure frameworks are practical and immediately actionable
- Sample prompts should feel like real user questions
- This will be used in production - make it exceptional

**Tone & Style Guidance:**
- Style "%s" means: %s
- Tone "%s" means: %s
- Verbosity "%s" means: %s

Generate the structured output following the schema. Make it production-ready and exceptional.`, 
		name, tagline, b.specialty, b.style, b.tone, b.verbosity,
		b.getCustomPromptSection(),
		b.specialty,
		b.style, b.tone, tagline,
		b.style, b.tone,
		b.specialty,
		b.style, b.getStyleDescription(),
		b.tone, b.getToneDescription(),
		b.verbosity, b.getVerbosityDescription())
}

func (b *CoachSpecBuilder) getStyleDescription() string {
	descriptions := map[string]string{
		"direct":            "clear, actionable guidance without unnecessary fluff",
		"warm":              "encouraging and empathetic support",
		"supportive":        "encouraging and empathetic support",
		"warm & supportive": "encouraging and empathetic support",
		"socratic":          "thoughtful questions rather than direct answers",
		"analytical":        "systematic and logical problem breakdown",
		"motivational":      "inspiring action and building confidence",
		"pragmatic":         "practical, real-world solutions",
	}
	if desc, ok := descriptions[b.style]; ok {
		return desc
	}
	return "balanced, professional coaching approach"
}

func (b *CoachSpecBuilder) getToneDescription() string {
	descriptions := map[string]string{
		"gentle":   "soft, patient, and understanding",
		"balanced": "professional yet approachable",
		"intense":  "direct, urgent, and high-energy",
	}
	if desc, ok := descriptions[b.tone]; ok {
		return desc
	}
	return "balanced and professional"
}

func (b *CoachSpecBuilder) getVerbosityDescription() string {
	descriptions := map[string]string{
		"low":    "concise, minimal responses (1-2 sentences)",
		"medium": "balanced responses (2-4 sentences)",
		"high":   "detailed, comprehensive responses (4+ sentences)",
	}
	if desc, ok := descriptions[b.verbosity]; ok {
		return desc
	}
	return "balanced response length"
}

func (b *CoachSpecBuilder) getCustomPromptSection() string {
	if b.customPrompt != "" {
		return fmt.Sprintf("- Custom Instructions: %s", b.customPrompt)
	}
	return ""
}

// buildIdentity creates the identity section
func (b *CoachSpecBuilder) buildIdentity(name, tagline string) models.Identity {
	// Generate problem statements based on specialty
	problemStatements := b.generateProblemStatements()
	
	// Generate outcomes based on specialty
	outcomes := b.generateOutcomes()
	
	// Generate or use provided sample prompts
	samplePrompts := b.samplePrompts
	if len(samplePrompts) == 0 {
		samplePrompts = b.generateSamplePrompts()
	}

	return models.Identity{
		Name:              name,
		Tagline:           tagline,
		Niche:             b.specialty,
		Audience:          b.audience,
		ProblemStatements: problemStatements,
		Outcomes:          outcomes,
		Persona: models.Persona{
			Archetype:  b.getArchetype(),
			Voice:      b.buildVoiceDescription(),
			Boundaries: []string{"no therapy", "no medical advice", "no legal advice"},
		},
		SamplePrompts: samplePrompts,
	}
}

// buildStyle creates the style section
func (b *CoachSpecBuilder) buildStyle() models.Style {
	formatting := b.getFormattingForStyle()
	interactionRules := b.getInteractionRulesForStyle()

	return models.Style{
		Tone:             b.getToneValue(),
		Verbosity:        b.verbosity,
		Formatting:       formatting,
		InteractionRules: interactionRules,
	}
}

// buildMethods creates the methods section with frameworks
func (b *CoachSpecBuilder) buildMethods() models.Methods {
	frameworks := b.getFrameworksForSpecialty()
	
	return models.Methods{
		Frameworks: frameworks,
		DefaultProtocols: models.DefaultProtocols{
			QuickNudge: models.Protocol{
				Template: []string{"Clarify the situation", "Suggest next step", "Confirm action"},
			},
			DeepSession: models.Protocol{
				Phases: []string{"Explore context", "Identify patterns", "Create plan", "Commit to action"},
			},
		},
	}
}

// buildPolicies creates comprehensive safety and privacy policies
func (b *CoachSpecBuilder) buildPolicies() models.Policies {
	return models.Policies{
		Refusals: models.Refusals{
			Medical:         true,
			Legal:           true,
			FinancialAdvice: "general_only",
			SelfHarm:        "escalate_support",
		},
		Privacy: models.Privacy{
			StoreSensitiveMemory: false,
			RedactPatterns:       []string{"ssn", "credit_card", "password", "api_key"},
			UserControls:         []string{"memory_export", "memory_delete", "memory_view"},
		},
		Safety: models.Safety{
			NoManipulation: true,
			NoGuilt:        true,
			NoShaming:      true,
		},
	}
}

// buildToolsAllowed creates tool permissions - ALL tools enabled by default
func (b *CoachSpecBuilder) buildToolsAllowed() models.ToolsAllowed {
	// All coaches get access to ALL available tools
	return models.ToolsAllowed{
		ClientTools: []string{
			"local_notification_schedule",
			"calendar_event_create",
			"reminder_create",
			"share_sheet_export",
		},
		ServerTools: []string{
			"memory_read",
			"memory_write",
			"plan_create",
			"plan_update",
			"plan_list_active",
			"checkin_schedule",
		},
		RequiresUserConfirmation: []string{
			"calendar_event_create",
			"reminder_create",
			"local_notification_schedule",
		},
	}
}

// buildOutputs creates output schemas and rendering hints
func (b *CoachSpecBuilder) buildOutputs() models.Outputs {
	return models.Outputs{
		Schemas: models.OutputSchemas{
			Plan: models.SchemaDefinition{
				Type:     "object",
				Required: []string{"title", "objective", "horizon", "milestones", "next_actions"},
				Properties: map[string]interface{}{
					"title":        map[string]string{"type": "string"},
					"objective":    map[string]string{"type": "string"},
					"horizon":      map[string]string{"type": "string"},
					"milestones":   map[string]string{"type": "array"},
					"next_actions": map[string]string{"type": "array"},
				},
			},
			NextAction: models.SchemaDefinition{
				Type:     "object",
				Required: []string{"id", "title", "duration_min", "energy", "when"},
				Properties: map[string]interface{}{
					"id":           map[string]string{"type": "string"},
					"title":        map[string]string{"type": "string"},
					"duration_min": map[string]string{"type": "integer"},
					"energy":       map[string]string{"type": "string"},
					"when":         map[string]string{"type": "string"},
				},
			},
			WeeklyReview: models.SchemaDefinition{
				Type:     "object",
				Required: []string{"wins", "misses", "root_causes", "next_week_focus", "commitments"},
				Properties: map[string]interface{}{
					"wins":             map[string]string{"type": "array"},
					"misses":           map[string]string{"type": "array"},
					"root_causes":      map[string]string{"type": "array"},
					"next_week_focus":  map[string]string{"type": "array"},
					"commitments":      map[string]string{"type": "array"},
				},
			},
		},
		RenderingHints: models.RenderingHints{
			PrimaryCard:         "next_actions",
			MaxCardsPerResponse: 2,
		},
	}
}

// Helper methods for generating content based on specialty and style

func (b *CoachSpecBuilder) getArchetype() string {
	styleArchetypes := map[string]string{
		"direct":            "strategist",
		"warm":              "mentor",
		"supportive":        "mentor",
		"warm & supportive": "mentor",
		"socratic":          "philosopher",
		"analytical":        "analyst",
		"motivational":      "champion",
		"pragmatic":         "practitioner",
	}

	if archetype, ok := styleArchetypes[b.style]; ok {
		return archetype
	}
	return "coach"
}

func (b *CoachSpecBuilder) getToneValue() string {
	styleTones := map[string]string{
		"direct":            "direct_clear",
		"warm":              "warm_encouraging",
		"supportive":        "warm_encouraging",
		"warm & supportive": "warm_encouraging",
		"socratic":          "socratic_clear",
		"analytical":        "analytical_supportive",
		"motivational":      "energetic_inspiring",
		"pragmatic":         "practical_grounded",
	}

	if tone, ok := styleTones[b.style]; ok {
		return tone
	}
	return "balanced_supportive"
}

func (b *CoachSpecBuilder) buildVoiceDescription() string {
	base := "You are a professional AI coach"
	
	if b.customPrompt != "" {
		return base + ". " + b.customPrompt
	}

	styleDescriptions := map[string]string{
		"direct":            "who provides clear, actionable guidance without unnecessary fluff",
		"warm":              "who offers encouraging and empathetic support",
		"supportive":        "who offers encouraging and empathetic support",
		"warm & supportive": "who offers encouraging and empathetic support",
		"socratic":          "who guides through thoughtful questions rather than direct answers",
		"analytical":        "who breaks down problems systematically and logically",
		"motivational":      "who inspires action and builds confidence",
		"pragmatic":         "who focuses on practical, real-world solutions",
	}

	if desc, ok := styleDescriptions[b.style]; ok {
		return base + " " + desc + "."
	}
	return base + "."
}

func (b *CoachSpecBuilder) getFormattingForStyle() models.Formatting {
	styleFormatting := map[string]models.Formatting{
		"direct": {
			MaxBullets:               5,
			MaxSentencesPerParagraph: 2,
			AlwaysEndWith:            []string{"What's your next step?"},
			UseEmoji:                 "never",
			AllowedMarkdown:          []string{"bullet_list", "numbered_list", "bold"},
		},
		"warm": {
			MaxBullets:               6,
			MaxSentencesPerParagraph: 3,
			AlwaysEndWith:            []string{"You've got this! What feels right to you?"},
			UseEmoji:                 "sparingly",
			AllowedMarkdown:          []string{"bullet_list", "numbered_list", "bold", "italic"},
		},
		"socratic": {
			MaxBullets:               4,
			MaxSentencesPerParagraph: 2,
			AlwaysEndWith:            []string{"What do you think?", "How does that sit with you?"},
			UseEmoji:                 "never",
			AllowedMarkdown:          []string{"bullet_list", "bold"},
		},
	}

	if formatting, ok := styleFormatting[b.style]; ok {
		return formatting
	}

	// Default formatting
	return models.Formatting{
		MaxBullets:               5,
		MaxSentencesPerParagraph: 2,
		AlwaysEndWith:            []string{"What would you like to do next?"},
		UseEmoji:                 "sparingly",
		AllowedMarkdown:          []string{"bullet_list", "numbered_list", "bold"},
	}
}

func (b *CoachSpecBuilder) getInteractionRulesForStyle() models.InteractionRules {
	return models.InteractionRules{
		AskOneQuestionAtATime:   true,
		ConfirmBeforeScheduling: true,
		AvoidMotivationalFluff:  b.style == "direct" || b.style == "analytical",
		ReflectUserLanguage:     true,
	}
}

func (b *CoachSpecBuilder) getFrameworksForSpecialty() []models.Framework {
	specialtyFrameworks := map[string][]models.Framework{
		"focus": {
			{
				ID:        "pomodoro",
				Name:      "Pomodoro Technique",
				Goal:      "Maintain focus through timed work sessions",
				Steps:     []string{"Set timer for 25 min", "Work without distraction", "Take 5 min break", "Repeat"},
				WhenToUse: []string{"deep_work", "avoiding_distraction"},
			},
			{
				ID:        "time_blocking",
				Name:      "Time Blocking",
				Goal:      "Structure day with dedicated time blocks",
				Steps:     []string{"List priorities", "Assign time blocks", "Protect blocks", "Review"},
				WhenToUse: []string{"planning_day", "managing_calendar"},
			},
		},
		"productivity": {
			{
				ID:        "gtd",
				Name:      "Getting Things Done",
				Goal:      "Capture, clarify, organize, and execute tasks",
				Steps:     []string{"Capture everything", "Clarify next actions", "Organize by context", "Review regularly", "Do"},
				WhenToUse: []string{"overwhelmed", "many_projects"},
			},
		},
		"decision": {
			{
				ID:        "decision_matrix",
				Name:      "Decision Matrix",
				Goal:      "Evaluate options systematically",
				Steps:     []string{"List options", "Define criteria", "Score each option", "Decide"},
				WhenToUse: []string{"multiple_options", "complex_decision"},
			},
			{
				ID:        "regret_minimization",
				Name:      "Regret Minimization",
				Goal:      "Choose based on long-term regret",
				Steps:     []string{"Project 10 years ahead", "Which choice minimizes regret?", "Decide"},
				WhenToUse: []string{"life_decision", "career_choice"},
			},
		},
		"planning": {
			{
				ID:        "okr",
				Name:      "OKR Framework",
				Goal:      "Set and track objectives and key results",
				Steps:     []string{"Define objective", "Set 3-5 key results", "Track progress", "Review"},
				WhenToUse: []string{"goal_setting", "quarterly_planning"},
			},
			{
				ID:        "weekly_review",
				Name:      "Weekly Review",
				Goal:      "Reflect and plan systematically",
				Steps:     []string{"Review wins", "Identify misses", "Plan next week", "Commit"},
				WhenToUse: []string{"weekly_planning", "reflection"},
			},
		},
		"creativity": {
			{
				ID:        "brainstorming",
				Name:      "Structured Brainstorming",
				Goal:      "Generate ideas without judgment",
				Steps:     []string{"Set timer", "Generate ideas rapidly", "No criticism", "Combine and refine"},
				WhenToUse: []string{"creative_block", "need_ideas"},
			},
		},
		"wellness": {
			{
				ID:        "habit_stacking",
				Name:      "Habit Stacking",
				Goal:      "Build new habits by linking to existing ones",
				Steps:     []string{"Identify existing habit", "Choose new habit", "Link them", "Practice"},
				WhenToUse: []string{"building_habits", "behavior_change"},
			},
		},
	}

	if frameworks, ok := specialtyFrameworks[b.specialty]; ok {
		return frameworks
	}

	// Return empty array for custom specialties
	return []models.Framework{}
}

func (b *CoachSpecBuilder) generateProblemStatements() []string {
	specialtyProblems := map[string][]string{
		"focus":        {"I'm easily distracted", "I can't maintain concentration", "I struggle to complete tasks"},
		"productivity": {"I have too much to do", "I'm not getting things done", "I feel overwhelmed"},
		"decision":     {"I'm stuck between options", "I second-guess my decisions", "I avoid making hard calls"},
		"planning":     {"I don't know where to start", "I need to organize my goals", "I want to plan better"},
		"creativity":   {"I'm experiencing creative block", "I need fresh ideas", "I want to ship more work"},
		"wellness":     {"I want to build better habits", "I need to manage stress", "I want to improve my health"},
		"business":     {"I need business strategy help", "I'm facing a business decision", "I want to grow my business"},
		"leadership":   {"I want to be a better leader", "I need to manage my team better", "I'm facing leadership challenges"},
		"learning":     {"I want to learn more effectively", "I need a learning plan", "I'm struggling to retain information"},
		"career":       {"I need career guidance", "I'm considering a career change", "I want to advance my career"},
	}

	if problems, ok := specialtyProblems[b.specialty]; ok {
		return problems
	}

	// Generic problems for custom specialties
	return []string{
		"I need guidance in this area",
		"I want to improve",
		"I'm facing challenges",
	}
}

func (b *CoachSpecBuilder) generateOutcomes() []string {
	specialtyOutcomes := map[string][]string{
		"focus":        {"Improved concentration", "Better task completion", "Reduced distractions"},
		"productivity": {"Clear priorities", "Efficient workflows", "Consistent progress"},
		"decision":     {"Clear decision framework", "Confidence in choices", "Faster decision velocity"},
		"planning":     {"Structured plans", "Clear goals", "Actionable steps"},
		"creativity":   {"More ideas", "Creative confidence", "Consistent output"},
		"wellness":     {"Better habits", "Improved health", "Reduced stress"},
		"business":     {"Clear strategy", "Better decisions", "Business growth"},
		"leadership":   {"Stronger leadership", "Better team dynamics", "Effective management"},
		"learning":     {"Faster learning", "Better retention", "Skill mastery"},
		"career":       {"Career clarity", "Professional growth", "Career advancement"},
	}

	if outcomes, ok := specialtyOutcomes[b.specialty]; ok {
		return outcomes
	}

	// Generic outcomes for custom specialties
	return []string{
		"Achieve clarity",
		"Take action",
		"Build momentum",
	}
}

func (b *CoachSpecBuilder) generateSamplePrompts() []string {
	specialtyPrompts := map[string][]string{
		"focus": {
			"I'm feeling stuck on a project",
			"Help me prioritize my tasks",
			"I keep getting distracted",
		},
		"productivity": {
			"Help me organize my work",
			"I have too many things to do",
			"Create a system for me",
		},
		"decision": {
			"I'm stuck between two options",
			"Help me make this decision",
			"What framework should I use?",
		},
		"planning": {
			"Help me plan my week",
			"I need to organize my goals",
			"Create a review system for me",
		},
		"creativity": {
			"I'm experiencing creative block",
			"Help me brainstorm ideas",
			"How do I ship more work?",
		},
		"wellness": {
			"Help me build better habits",
			"I need a wellness routine",
			"How do I manage stress?",
		},
		"business": {
			"Help me with my business strategy",
			"I need to make a business decision",
			"How do I grow my business?",
		},
		"leadership": {
			"How can I be a better leader?",
			"Help me with a team challenge",
			"I need leadership advice",
		},
		"learning": {
			"Help me learn this skill",
			"Create a learning plan for me",
			"How do I retain information better?",
		},
		"career": {
			"I'm considering a career change",
			"Help me advance my career",
			"I need career guidance",
		},
	}

	if prompts, ok := specialtyPrompts[b.specialty]; ok {
		return prompts
	}

	// Generic prompts for custom specialties
	return []string{
		"I need help with this",
		"Can you guide me?",
		"What should I do?",
	}
}
