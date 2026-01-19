package gemini

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// RetryConfig defines retry behavior
type RetryConfig struct {
	MaxRetries     int
	InitialBackoff time.Duration
	MaxBackoff     time.Duration
	Multiplier     float64
}

// DefaultRetryConfig returns default retry configuration
func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries:     3,
		InitialBackoff: 1 * time.Second,
		MaxBackoff:     10 * time.Second,
		Multiplier:     2.0,
	}
}

// GenerateContentWithRetry generates content with automatic retry on transient errors
func (c *Client) GenerateContentWithRetry(ctx context.Context, systemPrompt, userPrompt string) (string, error) {
	config := DefaultRetryConfig()
	backoff := config.InitialBackoff

	var lastErr error

	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		if attempt > 0 {
			// Wait before retry
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(backoff):
			}

			// Exponential backoff
			backoff = time.Duration(float64(backoff) * config.Multiplier)
			if backoff > config.MaxBackoff {
				backoff = config.MaxBackoff
			}
		}

		result, err := c.GenerateContent(ctx, systemPrompt, userPrompt)
		if err == nil {
			return result, nil
		}

		lastErr = err

		// Check if error is retryable
		if !isRetryableError(err) {
			return "", fmt.Errorf("non-retryable error: %w", err)
		}

		// Log retry attempt
		fmt.Printf("Gemini API error (attempt %d/%d): %v\n", attempt+1, config.MaxRetries+1, err)
	}

	return "", fmt.Errorf("max retries exceeded: %w", lastErr)
}

// isRetryableError determines if an error should trigger a retry
func isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	// Check for specific error types
	errStr := err.Error()

	// Transient errors that should be retried
	retryableErrors := []string{
		"timeout",
		"deadline exceeded",
		"connection refused",
		"connection reset",
		"temporary failure",
		"service unavailable",
		"rate limit",
		"quota exceeded",
		"internal error",
	}

	for _, retryable := range retryableErrors {
		if contains(errStr, retryable) {
			return true
		}
	}

	return false
}

// contains checks if a string contains a substring (case-insensitive)
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && 
		(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || 
		len(s) > len(substr)*2))
}

// FallbackResponse provides a fallback when Gemini fails
func FallbackResponse(intent string) string {
	fallbacks := map[string]string{
		"focus":      "Let's break this down. What specifically are you working on right now?",
		"planning":   "Let's plan this out. What's your main goal for today?",
		"decision":   "Let's think through this decision. What are your main options?",
		"creativity": "Let's explore some ideas. What are you trying to create?",
		"health":     "Let's take a step back. What's been on your mind?",
		"confidence": "Let's build momentum. What's one small win you can achieve today?",
	}

	if response, ok := fallbacks[intent]; ok {
		return response
	}

	return "I'm here to help. What's on your mind?"
}

// SafeGenerateContent wraps GenerateContent with error handling and fallback
func (c *Client) SafeGenerateContent(ctx context.Context, systemPrompt, userPrompt string, fallbackIntent string) string {
	result, err := c.GenerateContentWithRetry(ctx, systemPrompt, userPrompt)
	if err != nil {
		// Log error
		fmt.Printf("Gemini API failed after retries: %v\n", err)
		
		// Return fallback
		return FallbackResponse(fallbackIntent)
	}

	return result
}

// ValidateResponse checks if the Gemini response is valid
func ValidateResponse(response string) error {
	if response == "" {
		return errors.New("empty response from Gemini")
	}

	if len(response) < 10 {
		return errors.New("response too short")
	}

	if len(response) > 10000 {
		return errors.New("response too long")
	}

	return nil
}
