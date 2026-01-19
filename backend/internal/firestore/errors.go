package firestore

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// RetryConfig defines retry behavior for Firestore operations
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
		InitialBackoff: 100 * time.Millisecond,
		MaxBackoff:     5 * time.Second,
		Multiplier:     2.0,
	}
}

// WithRetry executes a function with automatic retry on transient errors
func WithRetry(ctx context.Context, operation func() error) error {
	config := DefaultRetryConfig()
	backoff := config.InitialBackoff

	var lastErr error

	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		if attempt > 0 {
			// Wait before retry
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(backoff):
			}

			// Exponential backoff
			backoff = time.Duration(float64(backoff) * config.Multiplier)
			if backoff > config.MaxBackoff {
				backoff = config.MaxBackoff
			}
		}

		err := operation()
		if err == nil {
			return nil
		}

		lastErr = err

		// Check if error is retryable
		if !isRetryableError(err) {
			return fmt.Errorf("non-retryable error: %w", err)
		}

		// Log retry attempt
		fmt.Printf("Firestore error (attempt %d/%d): %v\n", attempt+1, config.MaxRetries+1, err)
	}

	return fmt.Errorf("max retries exceeded: %w", lastErr)
}

// isRetryableError determines if a Firestore error should trigger a retry
func isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	// Check gRPC status codes
	st, ok := status.FromError(err)
	if ok {
		switch st.Code() {
		case codes.Unavailable,
			codes.DeadlineExceeded,
			codes.ResourceExhausted,
			codes.Aborted,
			codes.Internal:
			return true
		case codes.NotFound,
			codes.AlreadyExists,
			codes.PermissionDenied,
			codes.InvalidArgument:
			return false
		}
	}

	// Check error message
	errStr := err.Error()
	retryableErrors := []string{
		"timeout",
		"deadline exceeded",
		"unavailable",
		"connection refused",
		"connection reset",
		"temporary failure",
	}

	for _, retryable := range retryableErrors {
		if contains(errStr, retryable) {
			return true
		}
	}

	return false
}

// contains checks if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && 
		(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr))
}

// IsNotFound checks if an error is a "not found" error
func IsNotFound(err error) bool {
	if err == nil {
		return false
	}

	st, ok := status.FromError(err)
	if ok && st.Code() == codes.NotFound {
		return true
	}

	return contains(err.Error(), "not found")
}

// IsAlreadyExists checks if an error is an "already exists" error
func IsAlreadyExists(err error) bool {
	if err == nil {
		return false
	}

	st, ok := status.FromError(err)
	if ok && st.Code() == codes.AlreadyExists {
		return true
	}

	return contains(err.Error(), "already exists")
}

// IsPermissionDenied checks if an error is a "permission denied" error
func IsPermissionDenied(err error) bool {
	if err == nil {
		return false
	}

	st, ok := status.FromError(err)
	if ok && st.Code() == codes.PermissionDenied {
		return true
	}

	return contains(err.Error(), "permission denied")
}

// WrapError wraps a Firestore error with additional context
func WrapError(operation string, err error) error {
	if err == nil {
		return nil
	}

	return fmt.Errorf("%s: %w", operation, err)
}
