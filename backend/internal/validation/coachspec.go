package validation

import (
	"fmt"
	"strings"

	"simon-backend/internal/models"
)

// ValidateCoachSpec validates a CoachSpec structure
// Returns an error if validation fails, nil if valid
func ValidateCoachSpec(spec *models.CoachSpec) error {
	if spec == nil {
		// CoachSpec is optional, so nil is valid
		return nil
	}

	// Validate version
	if spec.Version == "" {
		return fmt.Errorf("coachSpec.version is required")
	}

	// Validate Identity
	if err := validateIdentity(&spec.Identity); err != nil {
		return fmt.Errorf("coachSpec.identity: %w", err)
	}

	// Validate Style
	if err := validateStyle(&spec.Style); err != nil {
		return fmt.Errorf("coachSpec.style: %w", err)
	}

	// Validate Methods
	if err := validateMethods(&spec.Methods); err != nil {
		return fmt.Errorf("coachSpec.methods: %w", err)
	}

	// Validate Policies
	if err := validatePolicies(&spec.Policies); err != nil {
		return fmt.Errorf("coachSpec.policies: %w", err)
	}

	// Validate ToolsAllowed
	if err := validateToolsAllowed(&spec.ToolsAllowed); err != nil {
		return fmt.Errorf("coachSpec.tools_allowed: %w", err)
	}

	// Validate Outputs
	if err := validateOutputs(&spec.Outputs); err != nil {
		return fmt.Errorf("coachSpec.outputs: %w", err)
	}

	return nil
}

func validateIdentity(identity *models.Identity) error {
	if identity.Name == "" {
		return fmt.Errorf("name is required")
	}
	if len(identity.Name) > 100 {
		return fmt.Errorf("name must be <= 100 characters")
	}

	if identity.Tagline == "" {
		return fmt.Errorf("tagline is required")
	}
	if len(identity.Tagline) > 200 {
		return fmt.Errorf("tagline must be <= 200 characters")
	}

	if identity.Niche == "" {
		return fmt.Errorf("niche is required")
	}

	if len(identity.Audience) == 0 {
		return fmt.Errorf("audience must have at least one entry")
	}

	if len(identity.Languages) == 0 {
		return fmt.Errorf("languages must have at least one entry")
	}

	// Validate Persona
	if identity.Persona.Archetype == "" {
		return fmt.Errorf("persona.archetype is required")
	}
	if identity.Persona.Voice == "" {
		return fmt.Errorf("persona.voice is required")
	}

	return nil
}

func validateStyle(style *models.Style) error {
	if style.Tone == "" {
		return fmt.Errorf("tone is required")
	}

	if style.Verbosity == "" {
		return fmt.Errorf("verbosity is required")
	}

	// Validate verbosity values
	validVerbosity := map[string]bool{
		"low":    true,
		"medium": true,
		"high":   true,
	}
	if !validVerbosity[style.Verbosity] {
		return fmt.Errorf("verbosity must be one of: low, medium, high")
	}

	// Validate Formatting
	if style.Formatting.MaxBullets < 0 {
		return fmt.Errorf("formatting.maxBullets must be >= 0")
	}
	if style.Formatting.MaxSentencesPerParagraph < 0 {
		return fmt.Errorf("formatting.maxSentencesPerParagraph must be >= 0")
	}

	// Validate allowed markdown
	validMarkdown := map[string]bool{
		"bullet_list":   true,
		"numbered_list": true,
		"bold":          true,
		"italic":        true,
		"code":          true,
		"heading":       true,
	}
	for _, md := range style.Formatting.AllowedMarkdown {
		if !validMarkdown[md] {
			return fmt.Errorf("formatting.allowedMarkdown contains invalid value: %s", md)
		}
	}

	return nil
}

func validateMethods(methods *models.Methods) error {
	// Frameworks are optional, but if present, validate them
	for i, framework := range methods.Frameworks {
		if framework.ID == "" {
			return fmt.Errorf("frameworks[%d].id is required", i)
		}
		if framework.Name == "" {
			return fmt.Errorf("frameworks[%d].name is required", i)
		}
		if framework.Goal == "" {
			return fmt.Errorf("frameworks[%d].goal is required", i)
		}
		if len(framework.Steps) == 0 {
			return fmt.Errorf("frameworks[%d].steps must have at least one entry", i)
		}
	}

	return nil
}

func validatePolicies(policies *models.Policies) error {
	// Validate financial_advice values
	if policies.Refusals.FinancialAdvice != "" {
		validFinancialAdvice := map[string]bool{
			"general_only": true,
			"none":         true,
		}
		if !validFinancialAdvice[policies.Refusals.FinancialAdvice] {
			return fmt.Errorf("refusals.financial_advice must be one of: general_only, none")
		}
	}

	// Validate self_harm values
	if policies.Refusals.SelfHarm != "" {
		validSelfHarm := map[string]bool{
			"escalate_support": true,
			"refuse":           true,
		}
		if !validSelfHarm[policies.Refusals.SelfHarm] {
			return fmt.Errorf("refusals.self_harm must be one of: escalate_support, refuse")
		}
	}

	// Validate redact patterns
	for i, pattern := range policies.Privacy.RedactPatterns {
		if pattern == "" {
			return fmt.Errorf("privacy.redactPatterns[%d] cannot be empty", i)
		}
	}

	return nil
}

func validateToolsAllowed(tools *models.ToolsAllowed) error {
	// Define valid tool IDs
	validClientTools := map[string]bool{
		"local_notification_schedule": true,
		"calendar_event_create":       true,
		"reminder_create":             true,
		"share_sheet_export":          true,
	}

	validServerTools := map[string]bool{
		"memory_read":       true,
		"memory_write":      true,
		"plan_create":       true,
		"plan_update":       true,
		"plan_list_active":  true,
		"checkin_schedule":  true,
	}

	// Validate client tools
	for _, tool := range tools.ClientTools {
		if !validClientTools[tool] {
			return fmt.Errorf("client_tools contains invalid tool: %s", tool)
		}
	}

	// Validate server tools
	for _, tool := range tools.ServerTools {
		if !validServerTools[tool] {
			return fmt.Errorf("server_tools contains invalid tool: %s", tool)
		}
	}

	// Validate requires_user_confirmation tools exist in client_tools
	clientToolsMap := make(map[string]bool)
	for _, tool := range tools.ClientTools {
		clientToolsMap[tool] = true
	}

	for _, tool := range tools.RequiresUserConfirmation {
		if !clientToolsMap[tool] {
			return fmt.Errorf("requires_user_confirmation contains tool not in client_tools: %s", tool)
		}
	}

	return nil
}

func validateOutputs(outputs *models.Outputs) error {
	// Validate schemas
	if err := validateSchemaDefinition("Plan", &outputs.Schemas.Plan); err != nil {
		return fmt.Errorf("schemas.Plan: %w", err)
	}
	if err := validateSchemaDefinition("NextAction", &outputs.Schemas.NextAction); err != nil {
		return fmt.Errorf("schemas.NextAction: %w", err)
	}
	if err := validateSchemaDefinition("WeeklyReview", &outputs.Schemas.WeeklyReview); err != nil {
		return fmt.Errorf("schemas.WeeklyReview: %w", err)
	}

	// Validate rendering hints
	if outputs.RenderingHints.PrimaryCard != "" {
		validPrimaryCards := map[string]bool{
			"next_actions":   true,
			"plan":           true,
			"weekly_review":  true,
		}
		if !validPrimaryCards[outputs.RenderingHints.PrimaryCard] {
			return fmt.Errorf("rendering_hints.primaryCard must be one of: next_actions, plan, weekly_review")
		}
	}

	if outputs.RenderingHints.MaxCardsPerResponse < 0 {
		return fmt.Errorf("rendering_hints.maxCardsPerResponse must be >= 0")
	}

	return nil
}

func validateSchemaDefinition(name string, schema *models.SchemaDefinition) error {
	if schema.Type == "" {
		return fmt.Errorf("type is required")
	}

	// Validate type values
	validTypes := map[string]bool{
		"object": true,
		"array":  true,
		"string": true,
		"number": true,
		"boolean": true,
		"integer": true,
	}
	if !validTypes[schema.Type] {
		return fmt.Errorf("type must be one of: object, array, string, number, boolean, integer")
	}

	// For object types, properties should be defined
	if schema.Type == "object" && len(schema.Properties) == 0 {
		return fmt.Errorf("object type must have properties defined")
	}

	// Validate required fields exist in properties
	if schema.Type == "object" {
		for _, requiredField := range schema.Required {
			if _, exists := schema.Properties[requiredField]; !exists {
				return fmt.Errorf("required field '%s' not found in properties", requiredField)
			}
		}
	}

	return nil
}

// ValidateCoachForCreate validates a coach before creation
func ValidateCoachForCreate(coach *models.Coach) error {
	// Basic field validation
	if coach.Title == "" || len(coach.Title) > 60 {
		return fmt.Errorf("title must be 1-60 characters")
	}

	if len(coach.Promise) > 140 {
		return fmt.Errorf("promise must be <= 140 characters")
	}

	// Validate CoachSpec if present
	if coach.CoachSpec != nil {
		if err := ValidateCoachSpec(coach.CoachSpec); err != nil {
			return err
		}
	}

	// At least one of Blueprint or CoachSpec must be present
	if coach.Blueprint == nil && coach.CoachSpec == nil {
		return fmt.Errorf("either blueprint or coachSpec must be provided")
	}

	return nil
}

// ValidateCoachForUpdate validates a coach before update
func ValidateCoachForUpdate(coach *models.Coach) error {
	// Basic field validation
	if coach.Title != "" && len(coach.Title) > 60 {
		return fmt.Errorf("title must be <= 60 characters")
	}

	if len(coach.Promise) > 140 {
		return fmt.Errorf("promise must be <= 140 characters")
	}

	// Validate CoachSpec if present
	if coach.CoachSpec != nil {
		if err := ValidateCoachSpec(coach.CoachSpec); err != nil {
			return err
		}
	}

	return nil
}

// SanitizeErrorMessage returns a user-friendly error message
func SanitizeErrorMessage(err error) string {
	if err == nil {
		return ""
	}

	msg := err.Error()
	
	// Make error messages more user-friendly
	msg = strings.ReplaceAll(msg, "coachSpec.", "CoachSpec ")
	msg = strings.ReplaceAll(msg, "identity.", "Identity ")
	msg = strings.ReplaceAll(msg, "style.", "Style ")
	msg = strings.ReplaceAll(msg, "methods.", "Methods ")
	msg = strings.ReplaceAll(msg, "policies.", "Policies ")
	msg = strings.ReplaceAll(msg, "tools_allowed.", "Tools ")
	msg = strings.ReplaceAll(msg, "outputs.", "Outputs ")
	
	return msg
}
