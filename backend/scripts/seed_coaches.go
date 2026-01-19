package main

import (
	"context"
	"log"
	"time"

	"cloud.google.com/go/firestore"
	"simon-backend/internal/models"
)

func main() {
	ctx := context.Background()

	// Initialize Firestore
	projectID := "simon-prod" // Change to your project ID
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer client.Close()

	log.Println("Seeding coaches...")

	coaches := []models.Coach{
		{
			ID:         "focus-sprint-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Focus Sprint Coach",
			Promise:    "Turn stuckness into a 20-minute next step.",
			Tags:       []string{"focus", "productivity", "systems"},
			Blueprint: map[string]interface{}{
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
				"framework": map[string]interface{}{
					"name": "focus_sprint",
					"steps": []map[string]string{
						{"id": "clarify", "label": "Clarify target"},
						{"id": "reduce", "label": "Reduce scope"},
						{"id": "commit", "label": "Commit next action"},
						{"id": "reflect", "label": "Reflect + systemize"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  1234,
				Saves:   567,
				Upvotes: 89,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:         "weekly-review-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Weekly Review Coach",
			Promise:    "Reflect on your week and plan the next one.",
			Tags:       []string{"planning", "reflection", "systems"},
			Blueprint: map[string]interface{}{
				"style": map[string]interface{}{
					"tone":          "warm_supportive",
					"questionStyle": "guided_reflection",
				},
				"rules": map[string]interface{}{
					"alwaysAskOneClarifyingQuestionFirst": false,
					"defaultAnswerShape":                  "structured_review",
					"offerSystemWhenUseful":               true,
					"respectContextVault":                 true,
				},
				"framework": map[string]interface{}{
					"name": "weekly_review",
					"steps": []map[string]string{
						{"id": "wins", "label": "Celebrate wins"},
						{"id": "blockers", "label": "Identify blockers"},
						{"id": "priorities", "label": "Set top 3 priorities"},
						{"id": "schedule", "label": "Schedule deep work"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  892,
				Saves:   423,
				Upvotes: 67,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:         "decision-matrix-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Decision Matrix Coach",
			Promise:    "Make tough decisions with clarity and confidence.",
			Tags:       []string{"decision", "clarity", "systems"},
			Blueprint: map[string]interface{}{
				"style": map[string]interface{}{
					"tone":          "socratic",
					"questionStyle": "probing_questions",
				},
				"rules": map[string]interface{}{
					"alwaysAskOneClarifyingQuestionFirst": true,
					"defaultAnswerShape":                  "decision_framework",
					"offerSystemWhenUseful":               true,
					"respectContextVault":                 true,
				},
				"framework": map[string]interface{}{
					"name": "decision_matrix",
					"steps": []map[string]string{
						{"id": "options", "label": "List all options"},
						{"id": "criteria", "label": "Define criteria"},
						{"id": "evaluate", "label": "Evaluate each option"},
						{"id": "decide", "label": "Make the call"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  654,
				Saves:   312,
				Upvotes: 45,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:         "creative-output-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Creative Output Coach",
			Promise:    "Ship creative work consistently without burnout.",
			Tags:       []string{"creativity", "shipping", "systems"},
			Blueprint: map[string]interface{}{
				"style": map[string]interface{}{
					"tone":          "encouraging",
					"questionStyle": "exploratory",
				},
				"rules": map[string]interface{}{
					"alwaysAskOneClarifyingQuestionFirst": false,
					"defaultAnswerShape":                  "creative_process",
					"offerSystemWhenUseful":               true,
					"respectContextVault":                 true,
				},
				"framework": map[string]interface{}{
					"name": "creative_output",
					"steps": []map[string]string{
						{"id": "ideate", "label": "Generate ideas"},
						{"id": "scope", "label": "Scope the project"},
						{"id": "execute", "label": "Execute in sprints"},
						{"id": "ship", "label": "Ship and iterate"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  543,
				Saves:   289,
				Upvotes: 38,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:         "habit-system-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Habit System Coach",
			Promise:    "Build habits that stick through smart systems.",
			Tags:       []string{"habits", "health", "systems"},
			Blueprint: map[string]interface{}{
				"style": map[string]interface{}{
					"tone":          "practical",
					"questionStyle": "action_oriented",
				},
				"rules": map[string]interface{}{
					"alwaysAskOneClarifyingQuestionFirst": true,
					"defaultAnswerShape":                  "habit_design",
					"offerSystemWhenUseful":               true,
					"respectContextVault":                 true,
				},
				"framework": map[string]interface{}{
					"name": "habit_system",
					"steps": []map[string]string{
						{"id": "trigger", "label": "Design the trigger"},
						{"id": "routine", "label": "Simplify the routine"},
						{"id": "reward", "label": "Build in rewards"},
						{"id": "track", "label": "Track progress"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  721,
				Saves:   398,
				Upvotes: 52,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			ID:         "confidence-builder-coach",
			OwnerUID:   "system",
			Visibility: "public",
			Title:      "Confidence Builder Coach",
			Promise:    "Build unshakeable confidence through action.",
			Tags:       []string{"confidence", "mindset", "growth"},
			Blueprint: map[string]interface{}{
				"style": map[string]interface{}{
					"tone":          "empowering",
					"questionStyle": "strength_based",
				},
				"rules": map[string]interface{}{
					"alwaysAskOneClarifyingQuestionFirst": false,
					"defaultAnswerShape":                  "confidence_building",
					"offerSystemWhenUseful":               true,
					"respectContextVault":                 true,
				},
				"framework": map[string]interface{}{
					"name": "confidence_builder",
					"steps": []map[string]string{
						{"id": "evidence", "label": "Gather evidence"},
						{"id": "reframe", "label": "Reframe the story"},
						{"id": "action", "label": "Take small action"},
						{"id": "reflect", "label": "Reflect on progress"},
					},
				},
			},
			Stats: models.CoachStats{
				Starts:  489,
				Saves:   234,
				Upvotes: 31,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}

	// Save coaches to Firestore
	for _, coach := range coaches {
		_, err := client.Collection("coaches").Doc(coach.ID).Set(ctx, coach)
		if err != nil {
			log.Printf("Error saving coach %s: %v", coach.ID, err)
			continue
		}
		log.Printf("✓ Seeded coach: %s", coach.Title)
	}

	log.Println("Seeding complete!")
}
