package tools

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"simon-backend/internal/models"
)

// MemoryService handles memory read/write operations
type MemoryService struct {
	fs *firestore.Client
}

// NewMemoryService creates a new memory service
func NewMemoryService(fs *firestore.Client) *MemoryService {
	return &MemoryService{fs: fs}
}

// MemoryReadRequest represents a memory read request
type MemoryReadRequest struct {
	UID   string `json:"uid"`
	Query string `json:"query"`
	Limit int    `json:"limit"`
}

// MemoryReadResponse represents a memory read response
type MemoryReadResponse struct {
	Hits []MemoryHit `json:"hits"`
}

// MemoryHit represents a memory search result
type MemoryHit struct {
	Type    string  `json:"type"` // "commitment", "preference", "note", "session_summary"
	ID      string  `json:"id"`
	Snippet string  `json:"snippet"`
	Score   float64 `json:"score"`
}

// MemoryWriteRequest represents a memory write request
type MemoryWriteRequest struct {
	UID   string      `json:"uid"`
	Patch MemoryPatch `json:"patch"`
}

// MemoryPatch represents changes to user memory
type MemoryPatch struct {
	CommitmentsAdd []models.Commitment    `json:"commitments_add,omitempty"`
	PreferencesSet map[string]interface{} `json:"preferences_set,omitempty"`
	Redactions     []string               `json:"redactions,omitempty"`
}

// Read performs a keyword search in user memory
func (s *MemoryService) Read(ctx context.Context, req MemoryReadRequest) (*MemoryReadResponse, error) {
	// Fetch user document
	userDoc, err := s.fs.Collection("users").Doc(req.UID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	var user models.User
	if err := userDoc.DataTo(&user); err != nil {
		return nil, fmt.Errorf("failed to parse user: %w", err)
	}

	hits := []MemoryHit{}
	queryLower := strings.ToLower(req.Query)

	// Search in memory summary
	if user.MemorySummary != "" && strings.Contains(strings.ToLower(user.MemorySummary), queryLower) {
		hits = append(hits, MemoryHit{
			Type:    "session_summary",
			ID:      "memory_summary",
			Snippet: user.MemorySummary,
			Score:   0.8,
		})
	}

	// Search in commitments
	for _, commitment := range user.Commitments {
		if strings.Contains(strings.ToLower(commitment.Text), queryLower) {
			hits = append(hits, MemoryHit{
				Type:    "commitment",
				ID:      commitment.ID,
				Snippet: commitment.Text,
				Score:   0.7,
			})
		}
	}

	// Search in values
	for _, value := range user.ContextVault.Values {
		if strings.Contains(strings.ToLower(value), queryLower) {
			hits = append(hits, MemoryHit{
				Type:    "preference",
				ID:      "value",
				Snippet: value,
				Score:   0.6,
			})
		}
	}

	// Search in goals
	for _, goal := range user.ContextVault.Goals {
		if strings.Contains(strings.ToLower(goal), queryLower) {
			hits = append(hits, MemoryHit{
				Type:    "preference",
				ID:      "goal",
				Snippet: goal,
				Score:   0.6,
			})
		}
	}

	// Limit results
	limit := req.Limit
	if limit == 0 {
		limit = 10
	}
	if len(hits) > limit {
		hits = hits[:limit]
	}

	return &MemoryReadResponse{Hits: hits}, nil
}

// Write updates user memory with privacy filtering
func (s *MemoryService) Write(ctx context.Context, req MemoryWriteRequest) error {
	// Privacy filter: check for sensitive patterns
	sensitivePatterns := []string{
		"password",
		"api_key",
		"api key",
		"credit card",
		"credit_card",
		"ssn",
		"social security",
		"secret",
		"token",
		"private key",
	}

	// Check commitments for sensitive data
	for _, commitment := range req.Patch.CommitmentsAdd {
		textLower := strings.ToLower(commitment.Text)
		for _, pattern := range sensitivePatterns {
			if strings.Contains(textLower, pattern) {
				return fmt.Errorf("rejected: contains sensitive pattern '%s'", pattern)
			}
		}

		// Check for credit card patterns (16 digits)
		creditCardRegex := regexp.MustCompile(`\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b`)
		if creditCardRegex.MatchString(commitment.Text) {
			return fmt.Errorf("rejected: contains credit card number")
		}

		// Check for SSN patterns (XXX-XX-XXXX)
		ssnRegex := regexp.MustCompile(`\b\d{3}[-]?\d{2}[-]?\d{4}\b`)
		if ssnRegex.MatchString(commitment.Text) {
			return fmt.Errorf("rejected: contains SSN")
		}
	}

	// Build Firestore updates
	updates := []firestore.Update{
		{
			Path:  "updated_at",
			Value: models.Now(),
		},
	}

	// Add commitments
	if len(req.Patch.CommitmentsAdd) > 0 {
		// Set IDs and timestamps for new commitments
		for i := range req.Patch.CommitmentsAdd {
			if req.Patch.CommitmentsAdd[i].ID == "" {
				req.Patch.CommitmentsAdd[i].ID = fmt.Sprintf("commit_%d", time.Now().UnixNano())
			}
			if req.Patch.CommitmentsAdd[i].CreatedAt.IsZero() {
				req.Patch.CommitmentsAdd[i].CreatedAt = models.Now()
			}
			if req.Patch.CommitmentsAdd[i].Status == "" {
				req.Patch.CommitmentsAdd[i].Status = "active"
			}
		}

		// Convert to []interface{} for ArrayUnion
		commitmentsInterface := make([]interface{}, len(req.Patch.CommitmentsAdd))
		for i, c := range req.Patch.CommitmentsAdd {
			commitmentsInterface[i] = c
		}

		updates = append(updates, firestore.Update{
			Path:  "commitments",
			Value: firestore.ArrayUnion(commitmentsInterface...),
		})
	}

	// Set preferences
	if len(req.Patch.PreferencesSet) > 0 {
		for key, value := range req.Patch.PreferencesSet {
			updates = append(updates, firestore.Update{
				Path:  fmt.Sprintf("preferences.%s", key),
				Value: value,
			})
		}
	}

	// Apply updates
	_, err := s.fs.Collection("users").Doc(req.UID).Update(ctx, updates)
	if err != nil {
		return fmt.Errorf("failed to update user memory: %w", err)
	}

	return nil
}
