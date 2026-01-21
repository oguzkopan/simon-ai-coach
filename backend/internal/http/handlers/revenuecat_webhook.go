package handlers

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"simon-backend/internal/config"
	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/logger"
	"simon-backend/internal/models"
)

// RevenueCatWebhookHandler handles RevenueCat webhook events
type RevenueCatWebhookHandler struct {
	fs     *fsClient.Client
	config config.Config
	logger *logger.Logger
}

// NewRevenueCatWebhookHandler creates a new RevenueCat webhook handler
func NewRevenueCatWebhookHandler(fs *fsClient.Client, cfg config.Config, log *logger.Logger) *RevenueCatWebhookHandler {
	return &RevenueCatWebhookHandler{
		fs:     fs,
		config: cfg,
		logger: log,
	}
}

// RevenueCatWebhookPayload represents the incoming webhook payload
type RevenueCatWebhookPayload struct {
	Event struct {
		Type              string   `json:"type"`
		AppUserID         string   `json:"app_user_id"`
		OriginalAppUserID string   `json:"original_app_user_id"`
		ProductID         string   `json:"product_id"`
		EntitlementIDs    []string `json:"entitlement_ids"`
		PeriodType        string   `json:"period_type"`
		PurchasedAtMs     int64    `json:"purchased_at_ms"`
		ExpirationAtMs    int64    `json:"expiration_at_ms"`
		Store             string   `json:"store"`
		Environment       string   `json:"environment"`
	} `json:"event"`
	APIVersion string `json:"api_version"`
}

// HandleWebhook processes RevenueCat webhook events
func (h *RevenueCatWebhookHandler) HandleWebhook(c *gin.Context) {
	// Read the raw body for signature verification
	bodyBytes, err := io.ReadAll(c.Request.Body)
	if err != nil {
		h.logger.Error(c.Request.Context(), "Failed to read webhook body", err, map[string]interface{}{})
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Verify webhook signature
	signature := c.GetHeader("X-Revenuecat-Signature")
	if !h.verifySignature(bodyBytes, signature) {
		h.logger.Warning(c.Request.Context(), "Invalid webhook signature", map[string]interface{}{})
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid signature"})
		return
	}

	// Parse the webhook payload
	var payload RevenueCatWebhookPayload
	if err := json.Unmarshal(bodyBytes, &payload); err != nil {
		h.logger.Error(c.Request.Context(), "Failed to parse webhook payload", err, map[string]interface{}{})
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}

	// Process the event
	if err := h.processEvent(c.Request.Context(), payload, bodyBytes); err != nil {
		h.logger.Error(c.Request.Context(), "Failed to process webhook event", err, map[string]interface{}{
			"event_type": payload.Event.Type,
		})
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process event"})
		return
	}

	h.logger.Info(c.Request.Context(), "Successfully processed webhook event", map[string]interface{}{
		"event_type":    payload.Event.Type,
		"app_user_id":   payload.Event.AppUserID,
	})

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

// verifySignature verifies the webhook signature using HMAC-SHA256
func (h *RevenueCatWebhookHandler) verifySignature(body []byte, signature string) bool {
	// Get the webhook secret from config
	secret := h.config.RevenueCatWebhookSecret
	if secret == "" {
		h.logger.Warning(context.Background(), "RevenueCat webhook secret not configured", map[string]interface{}{})
		// In development, allow unsigned webhooks
		return h.config.Port == "8080"
	}

	// Compute HMAC-SHA256
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	// Compare signatures
	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}

// processEvent processes a webhook event and updates Firestore
func (h *RevenueCatWebhookHandler) processEvent(ctx context.Context, payload RevenueCatWebhookPayload, rawBody []byte) error {
	// Store the event in revenuecat_events collection
	eventID := uuid.New().String()
	
	var purchasedAt, expirationAt *time.Time
	if payload.Event.PurchasedAtMs > 0 {
		t := time.Unix(payload.Event.PurchasedAtMs/1000, 0)
		purchasedAt = &t
	}
	if payload.Event.ExpirationAtMs > 0 {
		t := time.Unix(payload.Event.ExpirationAtMs/1000, 0)
		expirationAt = &t
	}

	var rawPayload map[string]interface{}
	json.Unmarshal(rawBody, &rawPayload)

	event := models.RevenueCatEvent{
		ID:                eventID,
		EventType:         payload.Event.Type,
		AppUserID:         payload.Event.AppUserID,
		OriginalAppUserID: payload.Event.OriginalAppUserID,
		ProductID:         payload.Event.ProductID,
		EntitlementIDs:    payload.Event.EntitlementIDs,
		PeriodType:        payload.Event.PeriodType,
		PurchasedAt:       purchasedAt,
		ExpirationAt:      expirationAt,
		Store:             payload.Event.Store,
		Environment:       payload.Event.Environment,
		RawPayload:        rawPayload,
		ProcessedAt:       models.Now(),
		CreatedAt:         models.Now(),
	}

	if _, err := h.fs.DB.Collection("revenuecat_events").Doc(eventID).Set(ctx, event); err != nil {
		return err
	}

	// Update user's subscription cache
	return h.updateSubscriptionCache(ctx, payload)
}

// updateSubscriptionCache updates the user's subscription cache
func (h *RevenueCatWebhookHandler) updateSubscriptionCache(ctx context.Context, payload RevenueCatWebhookPayload) error {
	uid := payload.Event.AppUserID
	if uid == "" {
		return nil // No user to update
	}

	// Build entitlements map
	entitlements := make(map[string]bool)
	for _, entitlementID := range payload.Event.EntitlementIDs {
		// Determine if entitlement is active based on event type
		isActive := h.isEntitlementActive(payload.Event.Type)
		entitlements[entitlementID] = isActive
	}

	var expiresDate *time.Time
	if payload.Event.ExpirationAtMs > 0 {
		t := time.Unix(payload.Event.ExpirationAtMs/1000, 0)
		expiresDate = &t
	}

	subscriptionCache := models.SubscriptionCache{
		Entitlements:      entitlements,
		ProductIdentifier: payload.Event.ProductID,
		ExpiresDate:       expiresDate,
		PeriodType:        payload.Event.PeriodType,
		Store:             payload.Event.Store,
		LastUpdated:       models.Now(),
	}

	// Update user document
	userRef := h.fs.DB.Collection("users").Doc(uid)
	_, err := userRef.Update(ctx, []firestore.Update{
		{
			Path:  "subscription_cache",
			Value: subscriptionCache,
		},
		{
			Path:  "updated_at",
			Value: models.Now(),
		},
	})

	return err
}

// isEntitlementActive determines if an entitlement is active based on event type
func (h *RevenueCatWebhookHandler) isEntitlementActive(eventType string) bool {
	activeEvents := map[string]bool{
		"INITIAL_PURCHASE":          true,
		"RENEWAL":                   true,
		"PRODUCT_CHANGE":            true,
		"UNCANCELLATION":            true,
		"NON_RENEWING_PURCHASE":     true,
		"SUBSCRIPTION_EXTENDED":     true,
	}

	inactiveEvents := map[string]bool{
		"CANCELLATION":              false,
		"EXPIRATION":                false,
		"BILLING_ISSUE":             false,
		"SUBSCRIBER_ALIAS":          false,
		"SUBSCRIPTION_PAUSED":       false,
	}

	if active, ok := activeEvents[eventType]; ok {
		return active
	}
	if active, ok := inactiveEvents[eventType]; ok {
		return active
	}

	// Default to false for unknown event types
	return false
}

// CheckEntitlement checks if a user has a specific entitlement
func CheckEntitlement(fs *fsClient.Client, uid string, entitlementID string) (bool, error) {
	userDoc, err := fs.DB.Collection("users").Doc(uid).Get(nil)
	if err != nil {
		return false, err
	}

	var user models.User
	if err := userDoc.DataTo(&user); err != nil {
		return false, err
	}

	// Check subscription cache
	if user.SubscriptionCache == nil {
		return false, nil
	}

	// Check if entitlement exists and is active
	if active, ok := user.SubscriptionCache.Entitlements[entitlementID]; ok {
		// Also check expiration date if present
		if user.SubscriptionCache.ExpiresDate != nil {
			if time.Now().After(*user.SubscriptionCache.ExpiresDate) {
				return false, nil
			}
		}
		return active, nil
	}

	return false, nil
}

// RequiresPro middleware checks if user has pro entitlement
func RequiresPro(fs *fsClient.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, exists := c.Get("uid")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			c.Abort()
			return
		}

		hasPro, err := CheckEntitlement(fs, uid.(string), "pro")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check entitlement"})
			c.Abort()
			return
		}

		if !hasPro {
			c.JSON(http.StatusForbidden, gin.H{
				"error":   "pro_required",
				"message": "This feature requires a Pro subscription",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
