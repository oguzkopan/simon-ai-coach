package handlers

import (
	"encoding/base64"
	"log"
	"strings"
	"time"

	"simon-backend/internal/config"
	"simon-backend/internal/elevenlabs"
	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator"
	"simon-backend/internal/sse"

	"github.com/gin-gonic/gin"
)

// VoiceStreamOrchestrator manages voice-over generation:
// Gemini (text) → Client (text display) + ElevenLabs (TTS) → Client (audio playback)
// Uses non-streaming TTS for reliability
type VoiceStreamOrchestrator struct {
	elevenLabsClient *elevenlabs.Client
}

// NewVoiceStreamOrchestrator creates a new voice stream orchestrator
func NewVoiceStreamOrchestrator(cfg config.Config) *VoiceStreamOrchestrator {
	var client *elevenlabs.Client
	if cfg.ElevenLabsAPIKey != "" {
		client = elevenlabs.NewClient(cfg.ElevenLabsAPIKey)
	}

	return &VoiceStreamOrchestrator{
		elevenLabsClient: client,
	}
}

// StreamWithVoice handles streaming with voice-over enabled
// Uses non-streaming TTS for reliability - collects all text then generates audio
func (vso *VoiceStreamOrchestrator) StreamWithVoice(
	c *gin.Context,
	fs *fsClient.Client,
	output *orchestrator.PipelineOutput,
	coachVoiceConfig *models.VoiceConfig,
	sessionID string,
	flusher func(),
) error {
	if vso.elevenLabsClient == nil {
		log.Printf("⚠️ ElevenLabs client not configured, falling back to text-only streaming")
		return nil
	}

	if coachVoiceConfig == nil {
		log.Printf("⚠️ Coach voice config is nil, falling back to text-only streaming")
		return nil
	}

	voiceID := coachVoiceConfig.VoiceID
	if voiceID == "" {
		log.Printf("⚠️ Coach voice ID not set, falling back to text-only streaming")
		return nil
	}

	log.Printf("🎙️ Starting voice-over with voice: %s (non-streaming TTS)", voiceID)

	// Create voice settings from coach config
	settings := &elevenlabs.VoiceSettings{
		Stability:       coachVoiceConfig.Stability,
		SimilarityBoost: coachVoiceConfig.Similarity,
	}
	if coachVoiceConfig.Style != 0 {
		settings.Style = coachVoiceConfig.Style
	}

	// Collect all text and stream events to client
	var fullText strings.Builder
	var assistantMessageID string
	var assistantMessageText string
	eventID := 0

	for {
		select {
		case event, ok := <-output.Stream:
			if !ok {
				// Stream closed - generate audio for complete text
				if fullText.Len() > 0 {
					log.Printf("🎙️ Generating audio for %d characters", fullText.Len())
					
					// Generate complete audio (non-streaming)
					audioData, err := vso.elevenLabsClient.TextToSpeech(
						voiceID,
						fullText.String(),
						settings,
					)
					
					if err != nil {
						log.Printf("❌ Failed to generate audio: %v", err)
					} else {
						// Send audio as single chunk
						audioBase64 := base64.StdEncoding.EncodeToString(audioData)
						sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
							"audio":    audioBase64,
							"is_final": false,
						})
						flusher()
						
						log.Printf("✅ Audio generated: %d bytes", len(audioData))
					}
					
					// Send final marker
					sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
						"audio":    "",
						"is_final": true,
					})
					flusher()
				}

				// Save assistant message
				if assistantMessageText != "" && assistantMessageID != "" {
					assistantMsg := models.Message{
						ID:          assistantMessageID,
						Role:        "assistant",
						ContentText: assistantMessageText,
						Attachments: nil,
						CreatedAt:   time.Now(),
					}

					_, err := fs.DB.Collection("sessions").Doc(sessionID).
						Collection("messages").Doc(assistantMsg.ID).Set(c.Request.Context(), assistantMsg)
					if err != nil {
						log.Printf("❌ Error saving assistant message: %v", err)
					} else {
						log.Printf("✅ Saved assistant message: %s", assistantMessageID)
					}
				}

				return nil
			}

			eventID++

			// Collect text
			if event.Type == "message.delta" {
				if delta, ok := event.Data["delta"].(string); ok {
					fullText.WriteString(delta)
					assistantMessageText += delta
				}
			}

			// Track message ID
			if event.Type == "message.final" {
				if msgID, ok := event.Data["message_id"].(string); ok {
					assistantMessageID = msgID
				}
				if text, ok := event.Data["text"].(string); ok {
					assistantMessageText = text
				}
			}

			// Forward all events to client EXCEPT stream.done
			if event.Type != "stream.done" {
				if err := sse.Event(c.Writer, event.Type, event.Data); err != nil {
					log.Printf("❌ Error writing SSE event: %v", err)
					return err
				}
				flusher()
			}

			// Exit on completion or error
			if event.Type == "stream.done" || event.Type == "error" {
				// Generate audio before sending stream.done
				if fullText.Len() > 0 {
					log.Printf("🎙️ Generating audio for %d characters", fullText.Len())
					
					audioData, err := vso.elevenLabsClient.TextToSpeech(
						voiceID,
						fullText.String(),
						settings,
					)
					
					if err != nil {
						log.Printf("❌ Failed to generate audio: %v", err)
					} else {
						audioBase64 := base64.StdEncoding.EncodeToString(audioData)
						sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
							"audio":    audioBase64,
							"is_final": false,
						})
						flusher()
						
						log.Printf("✅ Audio generated: %d bytes", len(audioData))
					}
					
					// Send final marker
					sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
						"audio":    "",
						"is_final": true,
					})
					flusher()
				}

				// Save assistant message
				if assistantMessageText != "" && assistantMessageID != "" {
					assistantMsg := models.Message{
						ID:          assistantMessageID,
						Role:        "assistant",
						ContentText: assistantMessageText,
						Attachments: nil,
						CreatedAt:   time.Now(),
					}

					_, err := fs.DB.Collection("sessions").Doc(sessionID).
						Collection("messages").Doc(assistantMsg.ID).Set(c.Request.Context(), assistantMsg)
					if err != nil {
						log.Printf("❌ Error saving assistant message: %v", err)
					} else {
						log.Printf("✅ Saved assistant message: %s", assistantMessageID)
					}
				}

				// Send stream.done
				if event.Type == "stream.done" {
					sse.Event(c.Writer, "stream.done", event.Data)
					flusher()
				}

				return nil
			}

		case <-c.Request.Context().Done():
			log.Printf("🛑 Client disconnected")
			return c.Request.Context().Err()
		}
	}
}
