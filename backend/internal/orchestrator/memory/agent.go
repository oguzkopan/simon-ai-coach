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
	coachID string,
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

	// Extract insights about the user
	insights, err := ma.extractInsights(ctx, uid, output.MessageText)
	if err != nil {
		// Non-fatal, continue without insights
		insights = []string{}
	}

	// Update session document with summary
	if err := ma.updateSessionSummary(ctx, sessionID, summary); err != nil {
		return fmt.Errorf("failed to update session: %w", err)
	}

	// Update user memory with commitments
	if len(commitments) > 0 {
		if err := ma.updateUserCommitments(ctx, uid, sessionID, coachID, commitments); err != nil {
			return fmt.Errorf("failed to update commitments: %w", err)
		}
	}

	// Update user memory with insights
	if len(insights) > 0 {
		if err := ma.updateUserInsights(ctx, uid, sessionID, insights); err != nil {
			return fmt.Errorf("failed to update insights: %w", err)
		}
	}

	// Update memory summary
	if len(insights) > 0 {
		if err := ma.UpdateMemorySummary(ctx, uid); err != nil {
			// Non-fatal, log and continue
			fmt.Printf("Failed to update memory summary: %v\n", err)
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
func (ma *MemoryAgent) updateUserCommitments(ctx context.Context, uid string, sessionID string, coachID string, commitments []string) error {
	// Convert commitments to structured format
	commitmentDocs := []interface{}{}
	for _, text := range commitments {
		commitmentDocs = append(commitmentDocs, map[string]interface{}{
			"id":         generateCommitmentID(),
			"text":       text,
			"created_at": time.Now().UTC(),
			"status":     "active",
			"session_id": sessionID,
			"coach_id":   coachID,
		})
	}

	// Update user document
	_, err := ma.fs.DB.Collection("users").Doc(uid).Update(ctx, []firestore.Update{
		{
			Path:  "commitments",
			Value: firestore.ArrayUnion(commitmentDocs...),
		},
		{
			Path:  "updated_at",
			Value: time.Now().UTC(),
		},
	})

	return err
}

// UpdateMemorySummary updates the user's overall memory summary
func (ma *MemoryAgent) UpdateMemorySummary(ctx context.Context, uid string) error {
	// Get current user
	user, err := ma.fs.GetUser(ctx, uid)
	if err != nil {
		return err
	}

	// Build context from structured memory
	var contextParts []string
	
	// Add structured memory if available
	if user.Memory != nil {
		if len(user.Memory.Values) > 0 {
			contextParts = append(contextParts, "Values:")
			for _, v := range user.Memory.Values {
				contextParts = append(contextParts, "- "+v.Text)
			}
		}
		
		if len(user.Memory.Goals) > 0 {
			contextParts = append(contextParts, "\nActive Goals:")
			for _, g := range user.Memory.Goals {
				if g.Status == "active" {
					contextParts = append(contextParts, "- "+g.Text)
				}
			}
		}
		
		if len(user.Memory.Insights) > 0 {
			contextParts = append(contextParts, "\nRecent Insights:")
			// Get last 5 insights
			count := len(user.Memory.Insights)
			start := 0
			if count > 5 {
				start = count - 5
			}
			for i := start; i < count; i++ {
				contextParts = append(contextParts, "- "+user.Memory.Insights[i].Text)
			}
		}
	}
	
	// Fallback to old context vault if no structured memory
	if len(contextParts) == 0 {
		if len(user.ContextVault.Values) > 0 {
			contextParts = append(contextParts, "Values: "+strings.Join(user.ContextVault.Values, ", "))
		}
		if len(user.ContextVault.Goals) > 0 {
			contextParts = append(contextParts, "Goals: "+strings.Join(user.ContextVault.Goals, ", "))
		}
	}

	if len(contextParts) == 0 {
		// No context to summarize
		return nil
	}

	// Generate updated summary
	prompt := fmt.Sprintf(`Create a concise memory summary for this user based on their context.

User Context:
%s

Generate a 2-3 sentence summary that captures the essence of who this user is, what they're working on, and what matters to them. This will help coaches provide personalized guidance.

Summary:`, strings.Join(contextParts, "\n"))

	updatedSummary, err := ma.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return err
	}

	// Update user document - use structured memory if available
	updates := []firestore.Update{
		{
			Path:  "updated_at",
			Value: time.Now().UTC(),
		},
	}
	
	if user.Memory != nil {
		updates = append(updates, firestore.Update{
			Path:  "memory.summary",
			Value: strings.TrimSpace(updatedSummary),
		})
		updates = append(updates, firestore.Update{
			Path:  "memory.updated_at",
			Value: time.Now().UTC(),
		})
	} else {
		// Fallback to old field
		updates = append(updates, firestore.Update{
			Path:  "memory_summary",
			Value: strings.TrimSpace(updatedSummary),
		})
	}

	_, err = ma.fs.DB.Collection("users").Doc(uid).Update(ctx, updates)
	return err
}

// extractInsights extracts key insights about the user from the conversation
func (ma *MemoryAgent) extractInsights(ctx context.Context, uid string, coachText string) ([]string, error) {
	prompt := fmt.Sprintf(`Analyze this coaching conversation and extract key insights about the USER (not the coach).

Focus on:
- Patterns in their behavior or thinking
- Preferences they've expressed
- Strengths they've demonstrated
- Challenges they're facing
- Important context about their life/work

Conversation:
%s

Return a JSON array of insight strings (max 3 most important):
["insight 1", "insight 2", "insight 3"]

Only include significant insights. If none, return empty array [].`, coachText)

	response, err := ma.geminiClient.GenerateContent(ctx, prompt, "")
	if err != nil {
		return nil, err
	}

	// Simple parsing - in production would use proper JSON parsing
	insights := []string{}
	
	// Remove brackets and quotes, split by comma
	cleaned := strings.Trim(response, "[]")
	cleaned = strings.TrimSpace(cleaned)
	if len(cleaned) > 0 {
		parts := strings.Split(cleaned, "\",")
		for _, part := range parts {
			insight := strings.Trim(strings.Trim(part, " "), "\"")
			insight = strings.TrimSpace(insight)
			if len(insight) > 0 {
				insights = append(insights, insight)
			}
		}
	}

	return insights, nil
}

// updateUserInsights adds insights to user's structured memory
func (ma *MemoryAgent) updateUserInsights(ctx context.Context, uid string, sessionID string, insights []string) error {
	// Get current user to check if they have structured memory
	user, err := ma.fs.GetUser(ctx, uid)
	if err != nil {
		return err
	}

	// Initialize structured memory if it doesn't exist
	if user.Memory == nil {
		_, err := ma.fs.DB.Collection("users").Doc(uid).Update(ctx, []firestore.Update{
			{
				Path: "memory",
				Value: map[string]interface{}{
					"insights":   []interface{}{},
					"values":     []interface{}{},
					"goals":      []interface{}{},
					"constraints": []interface{}{},
					"projects":   []interface{}{},
					"summary":    "",
					"updated_at": time.Now().UTC(),
				},
			},
		})
		if err != nil {
			return err
		}
	}

	// Convert insights to structured format
	insightDocs := []interface{}{}
	for _, text := range insights {
		insightDocs = append(insightDocs, map[string]interface{}{
			"id":         generateInsightID(),
			"text":       text,
			"created_at": time.Now().UTC(),
			"session_id": sessionID,
			"category":   "pattern", // Default category
		})
	}

	// Update user document
	_, err = ma.fs.DB.Collection("users").Doc(uid).Update(ctx, []firestore.Update{
		{
			Path:  "memory.insights",
			Value: firestore.ArrayUnion(insightDocs...),
		},
		{
			Path:  "memory.updated_at",
			Value: time.Now().UTC(),
		},
		{
			Path:  "updated_at",
			Value: time.Now().UTC(),
		},
	})

	return err
}

// Helper function to generate commitment ID
func generateCommitmentID() string {
	return fmt.Sprintf("commit_%d", time.Now().UnixNano())
}

// Helper function to generate insight ID
func generateInsightID() string {
	return fmt.Sprintf("insight_%d", time.Now().UnixNano())
}
