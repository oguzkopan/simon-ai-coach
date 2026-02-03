package handlers

import (
	"encoding/base64"
	"fmt"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/http/middleware"
)

// GenerateAvatarRequest represents the request to generate a coach avatar
type GenerateAvatarRequest struct {
	Prompt    string `json:"prompt" binding:"required"`
	Specialty string `json:"specialty"`
	Style     string `json:"style"`
}

// GenerateAvatarResponse represents the response with the generated avatar
type GenerateAvatarResponse struct {
	ImageData string `json:"imageData"` // Base64 encoded PNG
	MimeType  string `json:"mimeType"`
}

// GenerateAvatar generates a coach avatar using a placeholder for now
// TODO: Integrate with Gemini 3 Image Generation when available
func GenerateAvatar(geminiAPIKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.GetUID(c)

		var req GenerateAvatarRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		log.Printf("GenerateAvatar: uid=%s, specialty=%s, prompt=%s", uid, req.Specialty, req.Prompt)

		// Build enhanced prompt for coach avatar
		enhancedPrompt := buildAvatarPrompt(req)
		log.Printf("Enhanced prompt: %s", enhancedPrompt)

		// TODO: Replace with actual Gemini 3 Image Generation
		// For now, return a placeholder response
		// The client should handle this gracefully
		
		// Generate a simple placeholder SVG avatar
		placeholderSVG := generatePlaceholderAvatar(req.Specialty)
		imageData := base64.StdEncoding.EncodeToString([]byte(placeholderSVG))

		log.Printf("Generated placeholder avatar: uid=%s, size=%d bytes", uid, len(imageData))

		c.JSON(http.StatusOK, GenerateAvatarResponse{
			ImageData: imageData,
			MimeType:  "image/svg+xml",
		})
	}
}

// buildAvatarPrompt creates an enhanced prompt for avatar generation
func buildAvatarPrompt(req GenerateAvatarRequest) string {
	basePrompt := req.Prompt

	// Add specialty-specific styling
	specialtyStyle := ""
	switch req.Specialty {
	case "focus", "productivity":
		specialtyStyle = "professional, focused, energetic"
	case "planning", "strategy":
		specialtyStyle = "organized, strategic, thoughtful"
	case "creativity", "creative":
		specialtyStyle = "artistic, imaginative, vibrant"
	case "wellness", "health":
		specialtyStyle = "calm, balanced, nurturing"
	case "business":
		specialtyStyle = "confident, executive, polished"
	case "decision":
		specialtyStyle = "analytical, wise, decisive"
	default:
		specialtyStyle = "friendly, approachable, professional"
	}

	// Build comprehensive prompt
	prompt := fmt.Sprintf(
		"%s. Style: %s. A professional coach avatar with %s characteristics. "+
			"High quality portrait, 1:1 aspect ratio, clean background, modern aesthetic, "+
			"suitable for a coaching app interface. Photorealistic quality.",
		basePrompt,
		req.Style,
		specialtyStyle,
	)

	return prompt
}

// generatePlaceholderAvatar creates a simple SVG placeholder based on specialty
func generatePlaceholderAvatar(specialty string) string {
	// Color scheme based on specialty
	color := "#5856D6" // Default indigo
	icon := "★"

	switch specialty {
	case "focus":
		color = "#00C7BE" // Teal
		icon = "◎"
	case "planning":
		color = "#FF9500" // Orange
		icon = "📅"
	case "creativity":
		color = "#AF52DE" // Purple
		icon = "💡"
	case "decision":
		color = "#FF2D55" // Rose
		icon = "⚡"
	case "wellness":
		color = "#00C7BE" // Mint
		icon = "🍃"
	case "business":
		color = "#5856D6" // Indigo
		icon = "📊"
	}

	svg := fmt.Sprintf(`<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <rect width="512" height="512" fill="%s"/>
  <text x="256" y="320" font-size="200" text-anchor="middle" fill="white">%s</text>
</svg>`, color, icon)

	return svg
}
