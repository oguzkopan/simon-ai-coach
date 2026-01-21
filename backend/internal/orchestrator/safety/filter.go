package safety

import (
	"context"
	"fmt"
	"regexp"
	"strings"

	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator/coach"
)

// SafetyFilter enforces policy boundaries and safety constraints
type SafetyFilter struct {
	sensitivePatterns []*regexp.Regexp
}

// NewSafetyFilter creates a new safety filter
func NewSafetyFilter() *SafetyFilter {
	// Compile sensitive data patterns
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`(?i)password[:\s]+\S+`),
		regexp.MustCompile(`(?i)api[_\s]?key[:\s]+\S+`),
		regexp.MustCompile(`\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b`), // Credit card
		regexp.MustCompile(`\b\d{3}-\d{2}-\d{4}\b`),                        // SSN
		regexp.MustCompile(`(?i)secret[:\s]+\S+`),
		regexp.MustCompile(`(?i)token[:\s]+\S+`),
	}

	return &SafetyFilter{
		sensitivePatterns: patterns,
	}
}

// Validate checks if the coach output violates any policies
func (sf *SafetyFilter) Validate(
	ctx context.Context,
	output *coach.CoachOutput,
	spec *models.CoachSpec,
) error {
	// Check refusal policies
	if err := sf.checkRefusalPolicies(output.MessageText, spec); err != nil {
		return err
	}

	// Check privacy rules
	if err := sf.checkPrivacyRules(output.MessageText, spec); err != nil {
		return err
	}

	// Check tool consent requirements
	if err := sf.checkToolConsent(output.ToolRequests, spec); err != nil {
		return err
	}

	// Check for sensitive data
	if sf.containsSensitiveData(output.MessageText) {
		return fmt.Errorf("Response contains sensitive data and cannot be stored")
	}

	return nil
}

// checkRefusalPolicies enforces refusal boundaries
func (sf *SafetyFilter) checkRefusalPolicies(text string, spec *models.CoachSpec) error {
	lowerText := strings.ToLower(text)

	// Medical advice check
	if spec.Policies.Refusals.Medical {
		medicalKeywords := []string{
			"diagnose", "diagnosis", "prescribe", "prescription",
			"medication", "treatment", "cure", "disease",
			"symptom", "medical condition", "doctor should",
		}

		for _, keyword := range medicalKeywords {
			if strings.Contains(lowerText, keyword) {
				return fmt.Errorf("I can't provide medical advice. Please consult a healthcare professional")
			}
		}
	}

	// Legal advice check
	if spec.Policies.Refusals.Legal {
		legalKeywords := []string{
			"legal advice", "lawsuit", "sue", "attorney",
			"lawyer", "court", "legal rights", "contract law",
		}

		for _, keyword := range legalKeywords {
			if strings.Contains(lowerText, keyword) {
				return fmt.Errorf("I can't provide legal advice. Please consult a lawyer")
			}
		}
	}

	// Financial advice check
	if spec.Policies.Refusals.FinancialAdvice == "none" {
		financialKeywords := []string{
			"invest in", "stock pick", "buy stock", "sell stock",
			"financial advice", "portfolio", "trading",
		}

		for _, keyword := range financialKeywords {
			if strings.Contains(lowerText, keyword) {
				return fmt.Errorf("I can't provide financial advice. Please consult a financial advisor")
			}
		}
	}

	// Self-harm check
	if spec.Policies.Refusals.SelfHarm == "escalate_support" {
		harmKeywords := []string{
			"kill myself", "end my life", "suicide", "self-harm",
			"hurt myself", "want to die",
		}

		for _, keyword := range harmKeywords {
			if strings.Contains(lowerText, keyword) {
				return fmt.Errorf("I'm concerned about your safety. Please reach out to a crisis helpline or mental health professional immediately")
			}
		}
	}

	return nil
}

// checkPrivacyRules enforces privacy constraints
func (sf *SafetyFilter) checkPrivacyRules(text string, spec *models.CoachSpec) error {
	if !spec.Policies.Privacy.StoreSensitiveMemory {
		// Check for redact patterns
		for _, pattern := range spec.Policies.Privacy.RedactPatterns {
			if strings.Contains(strings.ToLower(text), strings.ToLower(pattern)) {
				return fmt.Errorf("Response contains sensitive pattern '%s' and cannot be stored", pattern)
			}
		}
	}

	return nil
}

// checkToolConsent ensures client tools require confirmation
func (sf *SafetyFilter) checkToolConsent(requests []coach.ToolRequest, spec *models.CoachSpec) error {
	for _, req := range requests {
		// Check if tool requires confirmation
		requiresConfirmation := false
		for _, tool := range spec.ToolsAllowed.RequiresUserConfirmation {
			if tool == req.Tool {
				requiresConfirmation = true
				break
			}
		}

		// If tool requires confirmation but request doesn't have it
		if requiresConfirmation && !req.RequiresConfirmation {
			return fmt.Errorf("Tool %s requires user confirmation", req.Tool)
		}

		// Check if tool is allowed
		if !sf.isToolAllowed(req.Tool, spec) {
			return fmt.Errorf("Tool %s is not allowed by this coach", req.Tool)
		}
	}

	return nil
}

// containsSensitiveData checks for sensitive patterns
func (sf *SafetyFilter) containsSensitiveData(text string) bool {
	for _, pattern := range sf.sensitivePatterns {
		if pattern.MatchString(text) {
			return true
		}
	}
	return false
}

// isToolAllowed checks if a tool is in the allowed list
func (sf *SafetyFilter) isToolAllowed(tool string, spec *models.CoachSpec) bool {
	allTools := append(spec.ToolsAllowed.ClientTools, spec.ToolsAllowed.ServerTools...)
	for _, t := range allTools {
		if t == tool {
			return true
		}
	}
	return false
}

// RedactSensitiveData removes sensitive information from text
func (sf *SafetyFilter) RedactSensitiveData(text string) string {
	redacted := text

	for _, pattern := range sf.sensitivePatterns {
		redacted = pattern.ReplaceAllString(redacted, "[REDACTED]")
	}

	return redacted
}

// ValidateMemoryWrite checks if memory write is safe
func (sf *SafetyFilter) ValidateMemoryWrite(content string) error {
	if sf.containsSensitiveData(content) {
		return fmt.Errorf("Memory write contains sensitive data")
	}

	return nil
}

// CheckManipulation detects manipulative language
func (sf *SafetyFilter) CheckManipulation(text string, spec *models.CoachSpec) error {
	if !spec.Policies.Safety.NoManipulation {
		return nil
	}

	lowerText := strings.ToLower(text)

	manipulativePatterns := []string{
		"you should feel guilty",
		"you're being lazy",
		"you're not trying hard enough",
		"you'll never succeed",
		"you're a failure",
		"you should be ashamed",
	}

	for _, pattern := range manipulativePatterns {
		if strings.Contains(lowerText, pattern) {
			return fmt.Errorf("Response contains manipulative language")
		}
	}

	return nil
}

// CheckShaming detects shaming language
func (sf *SafetyFilter) CheckShaming(text string, spec *models.CoachSpec) error {
	if !spec.Policies.Safety.NoShaming {
		return nil
	}

	lowerText := strings.ToLower(text)

	shamingPatterns := []string{
		"you should be embarrassed",
		"that's pathetic",
		"you're weak",
		"you're incompetent",
	}

	for _, pattern := range shamingPatterns {
		if strings.Contains(lowerText, pattern) {
			return fmt.Errorf("Response contains shaming language")
		}
	}

	return nil
}
