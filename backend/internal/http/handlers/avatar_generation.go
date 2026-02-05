package handlers

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"net/http"
	"time"

	"cloud.google.com/go/storage"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"simon-backend/internal/config"
	"simon-backend/internal/gemini"
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
	ImageURL  string `json:"imageUrl"`  // Public URL to the uploaded image
	ImageData string `json:"imageData"` // Base64 encoded image (for backward compatibility)
	MimeType  string `json:"mimeType"`
}

// GenerateAvatar generates a coach avatar using Gemini 3 Image Generation
func GenerateAvatar(geminiClient *gemini.Client, cfg config.Config) gin.HandlerFunc {
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

		// Create context with timeout for image generation
		ctx, cancel := context.WithTimeout(c.Request.Context(), 45*time.Second)
		defer cancel()

		log.Printf("Starting Gemini image generation for uid=%s", uid)
		
		// Generate image using Gemini 3
		imageData, mimeType, err := geminiClient.GenerateImage(ctx, enhancedPrompt)
		if err != nil {
			log.Printf("Failed to generate image with Gemini for uid=%s: %v, falling back to placeholder", uid, err)
			// Fall back to placeholder on error
			imageData = generatePlaceholderPNG(req.Specialty)
			mimeType = "image/png"
		} else {
			log.Printf("Successfully generated image with Gemini for uid=%s, size=%d bytes", uid, len(imageData))
		}

		// Upload to Firebase Storage
		imageURL, uploadErr := uploadAvatarToStorage(ctx, cfg.ProjectID, uid, imageData, mimeType)
		if uploadErr != nil {
			log.Printf("Failed to upload avatar to storage for uid=%s: %v", uid, uploadErr)
			// Fall back to base64 only if upload fails
			base64Image := base64.StdEncoding.EncodeToString(imageData)
			c.JSON(http.StatusOK, GenerateAvatarResponse{
				ImageURL:  "",
				ImageData: base64Image,
				MimeType:  mimeType,
			})
			return
		}

		log.Printf("Successfully uploaded avatar to storage for uid=%s, url=%s", uid, imageURL)

		// Encode to base64 for backward compatibility
		base64Image := base64.StdEncoding.EncodeToString(imageData)
		
		log.Printf("Returning avatar: uid=%s, size=%d bytes, mimeType=%s, url=%s", uid, len(imageData), mimeType, imageURL)

		c.JSON(http.StatusOK, GenerateAvatarResponse{
			ImageURL:  imageURL,
			ImageData: base64Image,
			MimeType:  mimeType,
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

	// Build comprehensive prompt optimized for Gemini Image Generation
	// IMPORTANT: Explicitly instruct NOT to include any text in the image
	prompt := fmt.Sprintf(
		"%s. Style: %s. A professional coach avatar with %s characteristics. "+
			"High quality portrait photograph, square 1:1 aspect ratio, 1024x1024 resolution, "+
			"clean background, modern aesthetic, suitable for a coaching app interface. "+
			"Photorealistic quality, professional headshot style, well-lit, sharp focus. "+
			"IMPORTANT: Do not include any text, words, letters, or captions in the image. "+
			"The image should be purely visual without any text overlay or labels.",
		basePrompt,
		req.Style,
		specialtyStyle,
	)

	return prompt
}

// generatePlaceholderPNG creates a simple PNG placeholder based on specialty
// Returns a 512x512 PNG with a colored background
func generatePlaceholderPNG(specialty string) []byte {
	// Color scheme based on specialty
	var bgColor color.RGBA
	
	switch specialty {
	case "focus":
		bgColor = color.RGBA{0, 199, 190, 255} // Teal
	case "planning":
		bgColor = color.RGBA{255, 149, 0, 255} // Orange
	case "creativity":
		bgColor = color.RGBA{175, 82, 222, 255} // Purple
	case "decision":
		bgColor = color.RGBA{255, 45, 85, 255} // Rose
	case "wellness":
		bgColor = color.RGBA{0, 199, 190, 255} // Mint
	case "business":
		bgColor = color.RGBA{88, 86, 214, 255} // Indigo
	default:
		bgColor = color.RGBA{88, 86, 214, 255} // Default indigo
	}
	
	// Create a 512x512 image
	width, height := 512, 512
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	
	// Fill with solid color
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, bgColor)
		}
	}
	
	// Encode to PNG
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		log.Printf("Error encoding PNG: %v", err)
		// Return a minimal valid PNG on error
		return []byte{
			0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
			0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
			0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
			0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
			0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
			0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
			0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
			0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
			0x42, 0x60, 0x82,
		}
	}
	
	return buf.Bytes()
}

// uploadAvatarToStorage uploads the avatar image to Firebase Storage and returns the public URL
func uploadAvatarToStorage(ctx context.Context, projectID, uid string, imageData []byte, mimeType string) (string, error) {
	// Create storage client
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	// Generate unique filename
	filename := fmt.Sprintf("avatars/%s/%s.png", uid, uuid.New().String())
	
	// Get bucket - Firebase Storage bucket format (newer format)
	bucketName := fmt.Sprintf("%s.firebasestorage.app", projectID)
	log.Printf("Uploading to bucket: %s, filename: %s", bucketName, filename)
	
	bucket := client.Bucket(bucketName)
	
	// Create object writer
	obj := bucket.Object(filename)
	writer := obj.NewWriter(ctx)
	writer.ContentType = mimeType
	writer.CacheControl = "public, max-age=31536000" // Cache for 1 year
	
	// Write image data
	if _, err := writer.Write(imageData); err != nil {
		writer.Close()
		return "", fmt.Errorf("failed to write image data: %w", err)
	}
	
	// Close writer
	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to close writer: %w", err)
	}
	
	log.Printf("Successfully uploaded to storage, setting ACL...")
	
	// Make the object publicly readable
	if err := obj.ACL().Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		log.Printf("Warning: failed to set ACL (object may not be publicly readable): %v", err)
		// Don't fail the request if ACL setting fails - the object is still uploaded
	}
	
	// Return public URL using Firebase Storage URL format
	publicURL := fmt.Sprintf("https://firebasestorage.googleapis.com/v0/b/%s/o/%s?alt=media", 
		bucketName, 
		// URL encode the filename
		fmt.Sprintf("avatars%%2F%s%%2F%s.png", uid, uuid.New().String()))
	
	// Better approach: use the standard GCS URL which works with public ACL
	publicURL = fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, filename)
	
	log.Printf("Avatar uploaded successfully, URL: %s", publicURL)
	return publicURL, nil
}
