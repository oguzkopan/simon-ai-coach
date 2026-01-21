package memory

import (
	"context"
	"fmt"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	firestoreClient "simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/orchestrator/coach"
)

// MemoryAgent handles async session summarization and memory updates
type MemoryAgent struct {
	fs           *firestoreClient.Client
	geminiClient *gemini.Client
}

// NewMemoryAgent creates a new memory agent
func NewMemoryAgent(fs *firestoreClient.Client, gm *gemini.Client) *MemoryAgent {
	return &MemoryAgent{
		fs:           fs,
		geminiClient: gm,
	}
}

// Update performs async memory update after a coaching session
func (ma *MemoryAgent) Update(
	ctx context.Context,
	sessionID string,
	uid string,
	output *coach.CoachOutput,
) error {
	// Generate session summary
	summary, err := ma.generateSummary(ctx, output.MessageText)
	if err != nil {
		return fmt.Errorf("failed to generate summary: %w", err)
	}

	// Extract commitments
	commitments, err := ma.extractCommitments(ctx, output.MessageText)
	if err != nil {
		// Non-fatal, continue without commitments
		commitments = []string{}
	}

	// Update session document with summary
	if err := ma.updateSessionSummary(ctx, sessionID, summary); err != nil {
		return fmt.Errorf("failed to update session: %w", err)
	}

	// Update user memory with commitments
	if len(commitments) > 0 {
		if err := ma.updateUserCommitments(ctx, uid, commitments); err != nil {
			return fmt.Errorf("failed to update commitments: %w", err)
		}
	}

	return nil
}

// generateSummary creates a 2-5 line summary of the session
func (ma *MemoryAgent) generateSummary(ctx context.Context, coachText string) (string, error) {
	prompt := fmt.Sprintf(`Summarize this coaching session in 2-5 lines. Focus on:
- Key insights
- Decisions made
- Commitments

Session:
%s

Summary (2-5 lines):`, coachText)

	summary, err := ma.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return "", err
	}

	// Trim and validate
	summary = strings.TrimSpace(summary)
	if len(summary) == 0 {
		return "Session completed", nil
	}

	return summary, nil
}

// extractCommitments extracts action commitments from the session
func (ma *MemoryAgent) extractCommitments(ctx context.Context, coachText string) ([]string, error) {
	prompt := fmt.Sprintf(`Extract specific commitments or action items from this coaching session.

Session:
%s

Return a JSON array of commitment strings:
["commitment 1", "commitment 2", ...]

Only include explicit commitments. If none, return empty array [].`, coachText)

	response, err := ma.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return nil, err
	}

	// Simple parsing - in production would use proper JSON parsing
	commitments := []string{}
	
	// Remove brackets and quotes, split by comma
	cleaned := strings.Trim(response, "[]")
	if len(cleaned) > 0 {
		parts := strings.Split(cleaned, ",")
		for _, part := range parts {
			commitment := strings.Trim(strings.Trim(part, " "), "\"")
			if len(commitment) > 0 {
				commitments = append(commitments, commitment)
			}
		}
	}

	return commitments, nil
}

// updateSessionSummary updates the session document with summary
func (ma *MemoryAgent) updateSessionSummary(ctx context.Context, sessionID string, summary string) error {
	// Update session document
	_, err := ma.fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, []firestore.Update{
		{
			Path:  "summary.text",
			Value: summary,
		},
		{
			Path:  "summary.generated_at",
			Value: time.Now().UTC(),
		},
		{
			Path:  "updated_at",
			Value: time.Now().UTC(),
		},
	})

	return err
}

// updateUserCommitments adds commitments to user document
func (ma *MemoryAgent) updateUserCommitments(ctx context.Context, uid string, commitments []string) error {
	// Convert commitments to structured format
	commitmentDocs := []interface{}{}
	for _, text := range commitments {
		commitmentDocs = append(commitmentDocs, map[string]interface{}{
			"id":         generateCommitmentID(),
			"text":       text,
			"created_at": time.Now().UTC(),
			"status":     "active",
		})
	}

	// Update user document
	_, err := ma.fs.DB.Collection("users").Doc(uid).Update(ctx, []firestore.Update{
		{
			Path:  "commitments",
			Value: firestore.ArrayUnion(commitmentDocs...),
		},
	})

	return err
}

// UpdateMemorySummary updates the user's overall memory summary
func (ma *MemoryAgent) UpdateMemorySummary(ctx context.Context, uid string, newInsight string) error {
	// Get current user
	user, err := ma.fs.GetUser(ctx, uid)
	if err != nil {
		return err
	}

	// Generate updated summary
	prompt := fmt.Sprintf(`Update this user's memory summary with new insight.

Current summary:
%s

New insight:
%s

Generate an updated summary (max 3-4 sentences) that incorporates the new insight.`, 
		user.MemorySummary, 
		newInsight)

	updatedSummary, err := ma.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return err
	}

	// Update user document
	_, err = ma.fs.DB.Collection("users").Doc(uid).Update(ctx, []firestore.Update{
		{
			Path:  "memory_summary",
			Value: strings.TrimSpace(updatedSummary),
		},
	})

	return err
}

// Helper function to generate commitment ID
func generateCommitmentID() string {
	return fmt.Sprintf("commit_%d", time.Now().UnixNano())
}
