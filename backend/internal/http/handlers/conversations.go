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
)

// ListSessions returns a list of user's sessions
func ListSessions(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)

		log.Printf("ListSessions: uid=%s", uid)

		// Query sessions
		iter := fs.DB.Collection("sessions").
			Where("uid", "==", uid).
			OrderBy("updated_at", firestore.Desc).
			Limit(20).
			Documents(ctx)
		defer iter.Stop()

		var sessions []models.Session
		for {
			doc, err := iter.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				log.Printf("Error iterating sessions: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list sessions"})
				return
			}

			var session models.Session
			if err := doc.DataTo(&session); err != nil {
				log.Printf("Error parsing session: %v", err)
				continue
			}
			sessions = append(sessions, session)
		}

		c.JSON(http.StatusOK, sessions)
	}
}

// CreateSession creates a new coaching session
func CreateSession(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)

		var req models.CreateSessionRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Validate coach exists
		if req.CoachID != "" {
			doc, err := fs.DB.Collection("coaches").Doc(req.CoachID).Get(ctx)
			if err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "coach not found"})
				return
			}

			var coach models.Coach
			if err := doc.DataTo(&coach); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse coach"})
				return
			}

			// Check visibility
			if coach.Visibility == "private" && coach.OwnerUID != uid {
				c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
				return
			}
		}

		// Create session
		var coachIDPtr *string
		if req.CoachID != "" {
			coachIDPtr = &req.CoachID
		}

		session := models.Session{
			ID:        uuid.New().String(),
			UID:       uid,
			CoachID:   coachIDPtr,
			Title:     "New Session",
			Mode:      "quick",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		// Save to Firestore
		_, err := fs.DB.Collection("sessions").Doc(session.ID).Set(ctx, session)
		if err != nil {
			log.Printf("Error creating session: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create session"})
			return
		}

		log.Printf("Created session: uid=%s, sessionID=%s, coachID=%s", uid, session.ID, req.CoachID)
		c.JSON(http.StatusCreated, session)
	}
}

// GetSession returns a single session by ID
func GetSession(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		log.Printf("GetSession: uid=%s, sessionID=%s", uid, sessionID)

		// Get session
		doc, err := fs.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}

		var session models.Session
		if err := doc.DataTo(&session); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse session"})
			return
		}

		// Check ownership
		if session.UID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		// Get messages
		messagesIter := fs.DB.Collection("sessions").Doc(sessionID).
			Collection("messages").
			OrderBy("created_at", firestore.Asc).
			Documents(ctx)
		defer messagesIter.Stop()

		var messages []models.Message
		for {
			msgDoc, err := messagesIter.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				log.Printf("Error iterating messages: %v", err)
				break
			}

			var msg models.Message
			if err := msgDoc.DataTo(&msg); err != nil {
				log.Printf("Error parsing message: %v", err)
				continue
			}
			messages = append(messages, msg)
		}

		c.JSON(http.StatusOK, gin.H{
			"session":  session,
			"messages": messages,
		})
	}
}
