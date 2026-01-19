package firestore

import (
	"context"

	"cloud.google.com/go/firestore"
	
	"simon-backend/internal/models"
)

type Client struct {
	DB *firestore.Client
}

func New(ctx context.Context, projectID string) (*Client, error) {
	db, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}

	return &Client{DB: db}, nil
}

func (c *Client) Close() error {
	return c.DB.Close()
}

// GetCoach retrieves a coach by ID
func (c *Client) GetCoach(ctx context.Context, coachID string) (*models.Coach, error) {
	var coach models.Coach
	
	err := WithRetry(ctx, func() error {
		doc, err := c.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			return WrapError("get coach", err)
		}
		
		return doc.DataTo(&coach)
	})
	
	if err != nil {
		return nil, err
	}
	
	return &coach, nil
}

// CreateSession creates a new session and returns its ID
func (c *Client) CreateSession(ctx context.Context, session models.Session) (string, error) {
	var sessionID string
	
	err := WithRetry(ctx, func() error {
		docRef := c.DB.Collection("sessions").NewDoc()
		session.ID = docRef.ID
		sessionID = docRef.ID
		
		_, err := docRef.Set(ctx, session)
		return WrapError("create session", err)
	})
	
	if err != nil {
		return "", err
	}
	
	return sessionID, nil
}

// AddMessage adds a message to a session
func (c *Client) AddMessage(ctx context.Context, sessionID string, message models.Message) error {
	return WithRetry(ctx, func() error {
		docRef := c.DB.Collection("sessions").Doc(sessionID).Collection("messages").NewDoc()
		message.ID = docRef.ID
		
		_, err := docRef.Set(ctx, message)
		return WrapError("add message", err)
	})
}

// GetSession retrieves a session by ID
func (c *Client) GetSession(ctx context.Context, sessionID string) (*models.Session, error) {
	var session models.Session
	
	err := WithRetry(ctx, func() error {
		doc, err := c.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			return WrapError("get session", err)
		}
		
		return doc.DataTo(&session)
	})
	
	if err != nil {
		return nil, err
	}
	
	return &session, nil
}

// GetUser retrieves a user by UID
func (c *Client) GetUser(ctx context.Context, uid string) (*models.User, error) {
	doc, err := c.DB.Collection("users").Doc(uid).Get(ctx)
	if err != nil {
		// If user doesn't exist, create default user
		if err.Error() == "not found" {
			user := &models.User{
				UID:         uid,
				ContextVault: models.UserContext{},
				Preferences: models.Preferences{
					IncludeContext: true,
				},
				CreatedAt: models.Now(),
				UpdatedAt: models.Now(),
			}
			
			if _, err := c.DB.Collection("users").Doc(uid).Set(ctx, user); err != nil {
				return nil, err
			}
			
			return user, nil
		}
		return nil, err
	}

	var user models.User
	if err := doc.DataTo(&user); err != nil {
		return nil, err
	}

	return &user, nil
}

// UpdateUser updates a user's profile
func (c *Client) UpdateUser(ctx context.Context, uid string, updates map[string]interface{}) error {
	updates["updated_at"] = models.Now()
	_, err := c.DB.Collection("users").Doc(uid).Set(ctx, updates, firestore.MergeAll)
	return err
}

// UpdateUserContext updates a user's context vault
func (c *Client) UpdateUserContext(ctx context.Context, uid string, contextVault models.UserContext) error {
	updates := map[string]interface{}{
		"context_vault": contextVault,
		"updated_at":    models.Now(),
	}
	_, err := c.DB.Collection("users").Doc(uid).Set(ctx, updates, firestore.MergeAll)
	return err
}

// UpdateUserPreference updates a specific user preference
func (c *Client) UpdateUserPreference(ctx context.Context, uid string, key string, value interface{}) error {
	updates := map[string]interface{}{
		"preferences." + key: value,
		"updated_at":         models.Now(),
	}
	_, err := c.DB.Collection("users").Doc(uid).Set(ctx, updates, firestore.MergeAll)
	return err
}

// DeleteAllUserData deletes all data for a user
func (c *Client) DeleteAllUserData(ctx context.Context, uid string) error {
	batch := c.DB.Batch()

	// Delete user document
	batch.Delete(c.DB.Collection("users").Doc(uid))

	// Delete coaches owned by user
	coachesQuery := c.DB.Collection("coaches").Where("owner_uid", "==", uid)
	coachesDocs, err := coachesQuery.Documents(ctx).GetAll()
	if err == nil {
		for _, doc := range coachesDocs {
			batch.Delete(doc.Ref)
		}
	}

	// Delete sessions
	sessionsQuery := c.DB.Collection("sessions").Where("uid", "==", uid)
	sessionsDocs, err := sessionsQuery.Documents(ctx).GetAll()
	if err == nil {
		for _, doc := range sessionsDocs {
			// Delete messages subcollection
			messages, _ := doc.Ref.Collection("messages").Documents(ctx).GetAll()
			for _, msg := range messages {
				batch.Delete(msg.Ref)
			}
			batch.Delete(doc.Ref)
		}
	}

	// Delete systems
	systemsQuery := c.DB.Collection("systems").Where("uid", "==", uid)
	systemsDocs, err := systemsQuery.Documents(ctx).GetAll()
	if err == nil {
		for _, doc := range systemsDocs {
			batch.Delete(doc.Ref)
		}
	}

	// Commit batch
	_, err = batch.Commit(ctx)
	return err
}
