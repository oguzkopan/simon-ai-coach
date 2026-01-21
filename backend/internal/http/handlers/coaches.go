package handlers

import (
	"log"
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"google.golang.org/api/iterator"

	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
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

		// Build query
		query := fs.DB.Collection("coaches").Where("visibility", "==", "public")

		if tag != "" {
			query = query.Where("tags", "array-contains", tag)
		}

		if featured == "true" {
			query = query.Where("featured", "==", true)
		}

		// Execute query
		iter := query.Documents(ctx)
		defer iter.Stop()

		var coaches []models.Coach
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

		log.Printf("Returning %d coaches", len(coaches))
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
func CreateCoach(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)

		var req models.Coach
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
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
			Visibility: "private", // Default to private
			Title:      req.Title,
			Promise:    req.Promise,
			Tags:       req.Tags,
			Blueprint:  req.Blueprint,
			CoachSpec:  req.CoachSpec, // Include CoachSpec if provided
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
		if req.CoachSpec != nil {
			updates = append(updates, firestore.Update{Path: "coachSpec", Value: req.CoachSpec})
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
