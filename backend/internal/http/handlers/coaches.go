package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"google.golang.org/api/iterator"
	"google.golang.org/genai"

	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/services"
	"simon-backend/internal/validation"
)

// ListCoaches returns a list of coaches (public endpoint)
func ListCoaches(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		
		// UID is optional for public browsing
		uid := ""
		if uidVal, exists := c.Get("uid"); exists {
			uid = uidVal.(string)
		}

		tag := c.Query("tag")
		featured := c.Query("featured")

		log.Printf("ListCoaches: uid=%s, tag=%s, featured=%s", uid, tag, featured)

		var coaches []models.Coach
		
		// If user is authenticated, get both public coaches AND their own private coaches
		if uid != "" {
			// Get public coaches
			publicQuery := fs.DB.Collection("coaches").Where("visibility", "==", "public")
			if tag != "" {
				publicQuery = publicQuery.Where("tags", "array-contains", tag)
			}
			if featured == "true" {
				publicQuery = publicQuery.Where("featured", "==", true)
			}
			
			publicIter := publicQuery.Documents(ctx)
			for {
				doc, err := publicIter.Next()
				if err == iterator.Done {
					break
				}
				if err != nil {
					log.Printf("Error iterating public coaches: %v", err)
					continue
				}
				
				var coach models.Coach
				if err := doc.DataTo(&coach); err != nil {
					log.Printf("Error parsing coach %s: %v", doc.Ref.ID, err)
					continue
				}
				coaches = append(coaches, coach)
			}
			publicIter.Stop()
			
			// Get user's own private coaches
			privateQuery := fs.DB.Collection("coaches").
				Where("visibility", "==", "private").
				Where("owner_uid", "==", uid)
			if tag != "" {
				privateQuery = privateQuery.Where("tags", "array-contains", tag)
			}
			
			privateIter := privateQuery.Documents(ctx)
			for {
				doc, err := privateIter.Next()
				if err == iterator.Done {
					break
				}
				if err != nil {
					log.Printf("Error iterating private coaches: %v", err)
					continue
				}
				
				var coach models.Coach
				if err := doc.DataTo(&coach); err != nil {
					log.Printf("Error parsing coach %s: %v", doc.Ref.ID, err)
					continue
				}
				coaches = append(coaches, coach)
			}
			privateIter.Stop()
		} else {
			// Not authenticated - only show public coaches
			query := fs.DB.Collection("coaches").Where("visibility", "==", "public")
			if tag != "" {
				query = query.Where("tags", "array-contains", tag)
			}
			if featured == "true" {
				query = query.Where("featured", "==", true)
			}
			
			iter := query.Documents(ctx)
			defer iter.Stop()
			
			for {
				doc, err := iter.Next()
				if err == iterator.Done {
					break
				}
				if err != nil {
					log.Printf("Error iterating coaches: %v", err)
					c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list coaches"})
					return
				}
				
				var coach models.Coach
				if err := doc.DataTo(&coach); err != nil {
					log.Printf("Error parsing coach %s: %v", doc.Ref.ID, err)
					continue
				}
				coaches = append(coaches, coach)
			}
		}

		log.Printf("Returning %d coaches (uid=%s)", len(coaches), uid)
		if len(coaches) == 0 {
			c.JSON(http.StatusOK, []models.Coach{})
		} else {
			c.JSON(http.StatusOK, coaches)
		}
	}
}

// GetCoach returns a single coach by ID (public endpoint)
func GetCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		coachID := c.Param("id")
		
		// UID is optional for public browsing
		uid := ""
		if uidVal, exists := c.Get("uid"); exists {
			uid = uidVal.(string)
		}

		log.Printf("GetCoach: uid=%s, coachID=%s", uid, coachID)

		doc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			log.Printf("Error getting coach: %v", err)
			c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
			return
		}

		var coach models.Coach
		if err := doc.DataTo(&coach); err != nil {
			log.Printf("Error parsing coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
			return
		}

		// Check visibility
		if coach.Visibility == "private" && coach.OwnerUID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		c.JSON(http.StatusOK, coach)
	}
}

// CreateCoach creates a new coach
func CreateCoach(fs *fsClient.Client, gm *gemini.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)

		var req models.Coach
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Extract specialty from tags (first tag)
		specialty := "general"
		if len(req.Tags) > 0 {
			specialty = req.Tags[0]
		}

		// ALWAYS use LLM to generate comprehensive CoachSpec
		// The client sends basic info, we enrich it with LLM
		if req.Title != "" && req.Promise != "" {
			log.Printf("Generating comprehensive CoachSpec with LLM for: %s (specialty: %s)", req.Title, specialty)
			
			// Extract style, tone, verbosity from CoachSpec if provided
			style := "direct"
			tone := "balanced"
			verbosity := "medium"
			customPrompt := ""
			
			if req.CoachSpec != nil {
				if req.CoachSpec.Style.Tone != "" {
					tone = req.CoachSpec.Style.Tone
				}
				if req.CoachSpec.Style.Verbosity != "" {
					verbosity = req.CoachSpec.Style.Verbosity
				}
				// Try to extract style from tone or other fields
				if req.CoachSpec.Identity.Persona.Voice != "" {
					customPrompt = req.CoachSpec.Identity.Persona.Voice
				}
			}
			
			// Build comprehensive CoachSpec using LLM
			builder := services.NewCoachSpecBuilder().
				WithSpecialty(specialty).
				WithStyle(style).
				WithTone(tone).
				WithVerbosity(verbosity).
				WithGeminiClient(gm) // Enable LLM-powered generation
			
			if customPrompt != "" {
				builder = builder.WithCustomPrompt(customPrompt)
			}

			req.CoachSpec = builder.Build(req.Title, req.Promise)
			
			// Generate rich tags using LLM based on the generated CoachSpec
			req.Tags = generateRichTagsWithLLM(ctx, gm, specialty, req.Title, req.CoachSpec)
			
			log.Printf("LLM generated comprehensive CoachSpec with %d problem statements, %d outcomes, %d sample prompts, %d frameworks, %d tags",
				len(req.CoachSpec.Identity.ProblemStatements),
				len(req.CoachSpec.Identity.Outcomes),
				len(req.CoachSpec.Identity.SamplePrompts),
				len(req.CoachSpec.Methods.Frameworks),
				len(req.Tags))
		}

		// Validate coach including CoachSpec
		if err := validation.ValidateCoachForCreate(&req); err != nil {
			errMsg := validation.SanitizeErrorMessage(err)
			log.Printf("Coach validation failed: %v", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": errMsg})
			return
		}

		// Create coach
		coach := models.Coach{
			ID:         uuid.New().String(),
			OwnerUID:   uid,
			Visibility: "public", // Default to public so coaches appear in browse
			Title:      req.Title,
			Promise:    req.Promise,
			Tags:       req.Tags,
			Blueprint:  req.Blueprint,
			AvatarURL:  req.AvatarURL, // Save avatar URL if provided
			CoachSpec:  req.CoachSpec, // Include LLM-generated CoachSpec
			Stats: models.CoachStats{
				Starts:  0,
				Saves:   0,
				Upvotes: 0,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		// Save to Firestore
		_, err := fs.DB.Collection("coaches").Doc(coach.ID).Set(ctx, coach)
		if err != nil {
			log.Printf("Error creating coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create coach"})
			return
		}

		log.Printf("Created coach: uid=%s, coachID=%s, hasCoachSpec=%v", uid, coach.ID, coach.CoachSpec != nil)
		c.JSON(http.StatusCreated, coach)
	}
}

// generateRichTagsWithLLM uses Gemini to generate relevant tags based on the coach's content
func generateRichTagsWithLLM(ctx context.Context, gm *gemini.Client, specialty, title string, spec *models.CoachSpec) []string {
	// Build a prompt for tag generation
	prompt := fmt.Sprintf(`You are an expert at categorizing and tagging coaching content.

Given this coach:
- Title: %s
- Specialty: %s
- Tagline: %s
- Problem Statements: %v
- Outcomes: %v
- Frameworks: %v
- Audience: %v

Generate 5-8 highly relevant, specific tags that describe what this coach helps with.

Requirements:
- Tags should be lowercase, single words or short phrases (e.g., "time_management", "wellness", "productivity")
- Include the specialty as the first tag
- Be specific and actionable (e.g., "decision_making" not just "decisions")
- Focus on what users will search for (skills, topics, outcomes)
- Include both broad categories and specific niches
- Avoid generic tags like "coaching" or "help"
- Mix of: skill areas, problem domains, outcomes, and methodologies

Examples:
- For a productivity coach: ["productivity", "time_management", "focus", "habits", "systems", "goal_setting"]
- For a wellness coach: ["wellness", "fitness", "nutrition", "health", "habits", "energy", "mindfulness"]
- For a career coach: ["career", "leadership", "professional_growth", "communication", "strategy", "decision_making"]

Return ONLY a JSON array of strings, nothing else.`, 
		title, 
		specialty,
		spec.Identity.Tagline,
		getFirstN(spec.Identity.ProblemStatements, 4),
		getFirstN(spec.Identity.Outcomes, 4),
		getFrameworkNames(spec.Methods.Frameworks),
		getFirstN(spec.Identity.Audience, 3))

	// Use Gemini to generate tags
	temperature := float32(0.4) // Slightly higher for more creative tags
	config := &genai.GenerateContentConfig{
		Temperature:      &temperature,
		MaxOutputTokens:  300,
		ResponseMIMEType: "application/json",
	}

	result, err := gm.Raw.Models.GenerateContent(ctx, gm.Model, genai.Text(prompt), config)
	if err != nil {
		log.Printf("Failed to generate tags with LLM, using fallback: %v", err)
		return []string{specialty}
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
		log.Printf("No tags generated by LLM, using fallback")
		return []string{specialty}
	}

	// Parse the JSON array
	var tags []string
	if err := json.Unmarshal([]byte(jsonText), &tags); err != nil {
		log.Printf("Failed to parse LLM tags, using fallback: %v", err)
		return []string{specialty}
	}

	// Ensure we have at least the specialty tag
	if len(tags) == 0 {
		tags = []string{specialty}
	}

	// Ensure specialty is first if not already
	hasSpecialty := false
	for _, tag := range tags {
		if tag == specialty {
			hasSpecialty = true
			break
		}
	}
	if !hasSpecialty {
		tags = append([]string{specialty}, tags...)
	}

	// Limit to 8 tags max
	if len(tags) > 8 {
		tags = tags[:8]
	}

	log.Printf("Generated %d tags with LLM: %v", len(tags), tags)
	return tags
}

// Helper functions
func getFirstN(items []string, n int) []string {
	if len(items) <= n {
		return items
	}
	return items[:n]
}

func getFrameworkNames(frameworks []models.Framework) []string {
	names := make([]string, len(frameworks))
	for i, f := range frameworks {
		names[i] = f.Name
	}
	return names
}

// ForkCoach creates a copy of an existing coach
func ForkCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		coachID := c.Param("id")

		// Get original coach
		doc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
			return
		}

		var original models.Coach
		if err := doc.DataTo(&original); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
			return
		}

		// Create fork
		fork := models.Coach{
			ID:         uuid.New().String(),
			OwnerUID:   uid,
			Visibility: "private",
			Title:      original.Title + " (Fork)",
			Promise:    original.Promise,
			Tags:       original.Tags,
			Blueprint:  original.Blueprint,
			CoachSpec:  original.CoachSpec, // Copy CoachSpec if present
			Stats: models.CoachStats{
				Starts:  0,
				Saves:   0,
				Upvotes: 0,
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		// Save to Firestore
		_, err = fs.DB.Collection("coaches").Doc(fork.ID).Set(ctx, fork)
		if err != nil {
			log.Printf("Error forking coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fork coach"})
			return
		}

		log.Printf("Forked coach: uid=%s, originalID=%s, forkID=%s", uid, coachID, fork.ID)
		c.JSON(http.StatusCreated, fork)
	}
}

// UpdateCoach updates an existing coach
func UpdateCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		coachID := c.Param("id")

		// Get existing coach
		doc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
			return
		}

		var existing models.Coach
		if err := doc.DataTo(&existing); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
			return
		}

		// Check ownership
		if existing.OwnerUID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		// Parse update request
		var req models.Coach
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Validate update including CoachSpec
		if err := validation.ValidateCoachForUpdate(&req); err != nil {
			errMsg := validation.SanitizeErrorMessage(err)
			log.Printf("Coach update validation failed: %v", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": errMsg})
			return
		}

		// Build update list
		updates := []firestore.Update{
			{Path: "updated_at", Value: time.Now()},
		}

		// Update fields if provided
		if req.Title != "" {
			updates = append(updates, firestore.Update{Path: "title", Value: req.Title})
		}
		if req.Promise != "" {
			updates = append(updates, firestore.Update{Path: "promise", Value: req.Promise})
		}
		if req.Tags != nil {
			updates = append(updates, firestore.Update{Path: "tags", Value: req.Tags})
		}
		if req.Blueprint != nil {
			updates = append(updates, firestore.Update{Path: "blueprint", Value: req.Blueprint})
		}
		if req.AvatarURL != "" {
			updates = append(updates, firestore.Update{Path: "avatar_url", Value: req.AvatarURL})
		}
		if req.CoachSpec != nil {
			updates = append(updates, firestore.Update{Path: "coachSpec", Value: req.CoachSpec})
		}
		if req.Visibility != "" {
			// Validate visibility value
			if req.Visibility == "public" || req.Visibility == "private" {
				updates = append(updates, firestore.Update{Path: "visibility", Value: req.Visibility})
			}
		}

		// Apply updates
		_, err = fs.DB.Collection("coaches").Doc(coachID).Update(ctx, updates)
		if err != nil {
			log.Printf("Error updating coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update coach"})
			return
		}

		// Fetch updated coach
		updatedDoc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch updated coach"})
			return
		}

		var updated models.Coach
		if err := updatedDoc.DataTo(&updated); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse updated coach"})
			return
		}

		log.Printf("Updated coach: uid=%s, coachID=%s, hasCoachSpec=%v", uid, coachID, updated.CoachSpec != nil)
		c.JSON(http.StatusOK, updated)
	}
}

// PublishCoach publishes a private coach (Pro feature)
func PublishCoach(fs *fsClient.Client, cfg interface{}) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		coachID := c.Param("id")

		// TODO: Check Pro entitlement (Week 3)
		// For now, allow all users to publish

		// Get coach
		doc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
			return
		}

		var coach models.Coach
		if err := doc.DataTo(&coach); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
			return
		}

		// Check ownership
		if coach.OwnerUID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		// Update visibility
		_, err = fs.DB.Collection("coaches").Doc(coachID).Update(ctx, []firestore.Update{
			{Path: "visibility", Value: "public"},
			{Path: "updated_at", Value: time.Now()},
		})
		if err != nil {
			log.Printf("Error publishing coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to publish coach"})
			return
		}

		coach.Visibility = "public"
		coach.UpdatedAt = time.Now()

		log.Printf("Published coach: uid=%s, coachID=%s", uid, coachID)
		c.JSON(http.StatusOK, coach)
	}
}

// SaveCoach saves a coach to user's saved list
func SaveCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		coachID := c.Param("id")

		// Verify coach exists
		coachDoc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
			return
		}

		var coach models.Coach
		if err := coachDoc.DataTo(&coach); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
			return
		}

		// Get or create user document
		userRef := fs.DB.Collection("users").Doc(uid)
		userDoc, err := userRef.Get(ctx)
		
		var savedCoaches []string
		if err == nil {
			// User exists, get current saved coaches
			var user models.User
			if err := userDoc.DataTo(&user); err == nil {
				savedCoaches = user.SavedCoaches
			}
		}

		// Check if already saved
		for _, id := range savedCoaches {
			if id == coachID {
				c.JSON(http.StatusOK, gin.H{"message": "coach already saved"})
				return
			}
		}

		// Add to saved coaches
		savedCoaches = append(savedCoaches, coachID)

		// Update user document
		_, err = userRef.Set(ctx, map[string]interface{}{
			"saved_coaches": savedCoaches,
			"updated_at":    time.Now(),
		}, firestore.MergeAll)
		if err != nil {
			log.Printf("Error saving coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save coach"})
			return
		}

		// Increment coach saves count
		_, err = fs.DB.Collection("coaches").Doc(coachID).Update(ctx, []firestore.Update{
			{Path: "stats.saves", Value: firestore.Increment(1)},
		})
		if err != nil {
			log.Printf("Error incrementing coach saves: %v", err)
		}

		log.Printf("Saved coach: uid=%s, coachID=%s", uid, coachID)
		c.JSON(http.StatusOK, gin.H{"message": "coach saved successfully"})
	}
}

// UnsaveCoach removes a coach from user's saved list
func UnsaveCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		coachID := c.Param("id")

		// Get user document
		userRef := fs.DB.Collection("users").Doc(uid)
		userDoc, err := userRef.Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}

		var user models.User
		if err := userDoc.DataTo(&user); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse user"})
			return
		}

		// Remove from saved coaches
		var updatedSavedCoaches []string
		found := false
		for _, id := range user.SavedCoaches {
			if id != coachID {
				updatedSavedCoaches = append(updatedSavedCoaches, id)
			} else {
				found = true
			}
		}

		if !found {
			c.JSON(http.StatusOK, gin.H{"message": "coach was not saved"})
			return
		}

		// Update user document
		_, err = userRef.Update(ctx, []firestore.Update{
			{Path: "saved_coaches", Value: updatedSavedCoaches},
			{Path: "updated_at", Value: time.Now()},
		})
		if err != nil {
			log.Printf("Error unsaving coach: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to unsave coach"})
			return
		}

		// Decrement coach saves count
		_, err = fs.DB.Collection("coaches").Doc(coachID).Update(ctx, []firestore.Update{
			{Path: "stats.saves", Value: firestore.Increment(-1)},
		})
		if err != nil {
			log.Printf("Error decrementing coach saves: %v", err)
		}

		log.Printf("Unsaved coach: uid=%s, coachID=%s", uid, coachID)
		c.JSON(http.StatusOK, gin.H{"message": "coach unsaved successfully"})
	}
}

// GetSavedCoaches returns user's saved coaches
func GetSavedCoaches(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)

		// Get user document
		userDoc, err := fs.DB.Collection("users").Doc(uid).Get(ctx)
		if err != nil {
			c.JSON(http.StatusOK, []models.Coach{})
			return
		}

		var user models.User
		if err := userDoc.DataTo(&user); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse user"})
			return
		}

		if len(user.SavedCoaches) == 0 {
			c.JSON(http.StatusOK, []models.Coach{})
			return
		}

		// Fetch all saved coaches
		var coaches []models.Coach
		for _, coachID := range user.SavedCoaches {
			coachDoc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
			if err != nil {
				log.Printf("Error fetching saved coach %s: %v", coachID, err)
				continue
			}

			var coach models.Coach
			if err := coachDoc.DataTo(&coach); err != nil {
				log.Printf("Error parsing saved coach %s: %v", coachID, err)
				continue
			}

			coaches = append(coaches, coach)
		}

		log.Printf("Returning %d saved coaches for uid=%s", len(coaches), uid)
		c.JSON(http.StatusOK, coaches)
	}
}
