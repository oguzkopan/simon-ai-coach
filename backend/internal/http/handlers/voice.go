package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/config"
	"simon-backend/internal/elevenlabs"
)

// VoiceHandler handles voice-related requests
type VoiceHandler struct {
	elevenLabsClient *elevenlabs.Client
}

// NewVoiceHandler creates a new voice handler
func NewVoiceHandler(cfg config.Config) *VoiceHandler {
	var client *elevenlabs.Client
	if cfg.ElevenLabsAPIKey != "" {
		client = elevenlabs.NewClient(cfg.ElevenLabsAPIKey)
	}

	return &VoiceHandler{
		elevenLabsClient: client,
	}
}

// ListVoices returns available ElevenLabs voices
func (h *VoiceHandler) ListVoices(c *gin.Context) {
	if h.elevenLabsClient == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "voice service not configured"})
		return
	}

	voices, err := h.elevenLabsClient.GetVoices()
	if err != nil {
		log.Printf("Error fetching voices: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch voices"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"voices": voices})
}

// GetVoice returns a specific voice by ID
func (h *VoiceHandler) GetVoice(c *gin.Context) {
	if h.elevenLabsClient == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "voice service not configured"})
		return
	}

	voiceID := c.Param("id")
	if voiceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "voice_id is required"})
		return
	}

	voice, err := h.elevenLabsClient.GetVoice(voiceID)
	if err != nil {
		log.Printf("Error fetching voice %s: %v", voiceID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch voice"})
		return
	}

	c.JSON(http.StatusOK, voice)
}

// GetVoicePresets returns common voice presets
func (h *VoiceHandler) GetVoicePresets(c *gin.Context) {
	presets := elevenlabs.GetVoicePresets()
	c.JSON(http.StatusOK, gin.H{"presets": presets})
}

// TextToSpeechRequest represents a TTS request
type TextToSpeechRequest struct {
	Text     string                      `json:"text" binding:"required"`
	VoiceID  string                      `json:"voice_id" binding:"required"`
	Settings *elevenlabs.VoiceSettings   `json:"settings,omitempty"`
}

// TextToSpeech converts text to speech
func (h *VoiceHandler) TextToSpeech(c *gin.Context) {
	if h.elevenLabsClient == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "voice service not configured"})
		return
	}

	var req TextToSpeechRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	audioData, err := h.elevenLabsClient.TextToSpeech(req.VoiceID, req.Text, req.Settings)
	if err != nil {
		log.Printf("Error generating speech: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate speech"})
		return
	}

	// Return audio as MP3
	c.Header("Content-Type", "audio/mpeg")
	c.Header("Content-Length", string(rune(len(audioData))))
	c.Data(http.StatusOK, "audio/mpeg", audioData)
}
