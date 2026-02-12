package handlers

import (
	"log"
	"strings"
	"sync"
	"time"

	"simon-backend/internal/config"
	"simon-backend/internal/elevenlabs"
	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator"
	"simon-backend/internal/sse"

	"github.com/gin-gonic/gin"
)

// VoiceStreamOrchestrator manages the double-stream pipeline:
// Gemini (text) → Client (text display) + ElevenLabs (TTS) → Client (audio playback)
type VoiceStreamOrchestrator struct {
	elevenLabsClient *elevenlabs.Client
	textChan         chan string
	audioChan        chan []byte
	errorChan        chan error
	done             chan struct{}
	wg               sync.WaitGroup
}

// NewVoiceStreamOrchestrator creates a new voice stream orchestrator
func NewVoiceStreamOrchestrator(cfg config.Config) *VoiceStreamOrchestrator {
	var client *elevenlabs.Client
	if cfg.ElevenLabsAPIKey != "" {
		client = elevenlabs.NewClient(cfg.ElevenLabsAPIKey)
	}

	return &VoiceStreamOrchestrator{
		elevenLabsClient: client,
		textChan:         make(chan string, 100),
		audioChan:        make(chan []byte, 100),
		errorChan:        make(chan error, 10),
		done:             make(chan struct{}),
	}
}

// StreamWithVoice handles streaming with voice-over enabled
// It creates a double-stream pipeline where text is sent to both the client and ElevenLabs
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

	log.Printf("🎙️ Starting voice-over streaming with voice: %s", voiceID)

	// Create voice settings from coach config
	settings := &elevenlabs.VoiceSettings{
		Stability:       coachVoiceConfig.Stability,
		SimilarityBoost: coachVoiceConfig.Similarity,
	}
	if coachVoiceConfig.Style != 0 {
		settings.Style = coachVoiceConfig.Style
	}

	// Create ElevenLabs streaming session
	session, err := vso.elevenLabsClient.NewStreamingSession(voiceID, settings)
	if err != nil {
		log.Printf("❌ Failed to create ElevenLabs session: %v", err)
		return err
	}
	defer session.Close()

	log.Printf("✅ ElevenLabs session created successfully")

	// Start goroutine to forward audio chunks to client
	vso.wg.Add(1)
	go func() {
		defer vso.wg.Done()
		for {
			select {
			case audioData, ok := <-session.AudioChan:
				if !ok {
					return
				}

				// Send audio chunk to client via SSE
				if err := sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
					"audio":    string(audioData),
					"is_final": false,
				}); err != nil {
					log.Printf("❌ Error sending audio chunk: %v", err)
					return
				}
				flusher()

			case err := <-session.ErrorChan:
				// Don't send timeout errors to client - they're expected when stream ends
				if !strings.Contains(err.Error(), "timeout") && !strings.Contains(err.Error(), "input_timeout_exceeded") {
					log.Printf("❌ ElevenLabs error: %v", err)
					sse.Event(c.Writer, "error", map[string]interface{}{
						"code":    "VOICE_STREAM_ERROR",
						"message": err.Error(),
					})
					flusher()
				}
				return

			case <-vso.done:
				log.Printf("🛑 Voice stream orchestrator done")
				return
			}
		}
	}()

	// Process pipeline events and send text to both client and ElevenLabs
	var textBuffer strings.Builder
	var assistantMessageID string
	var assistantMessageText string
	eventID := 0

	for {
		select {
		case event, ok := <-output.Stream:
			if !ok {
				// Send EOS to ElevenLabs to flush remaining audio
				if err := session.SendEOS(); err != nil {
					log.Printf("❌ Error sending EOS: %v", err)
				}

				// Wait for audio to finish streaming
				vso.wg.Wait()

				// Send final audio marker
				sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
					"audio":    "",
					"is_final": true,
				})
				flusher()

				return nil
			}

			eventID++

			// Handle message delta - send to both client and ElevenLabs
			if event.Type == "message.delta" {
				if delta, ok := event.Data["delta"].(string); ok {
					textBuffer.WriteString(delta)
					assistantMessageText += delta

					// Send text chunk to ElevenLabs for TTS
					if err := session.SendText(delta); err != nil {
						log.Printf("❌ Error sending text to ElevenLabs: %v", err)
					}
				}
			}

			// Track message ID from message.final event
			if event.Type == "message.final" {
				if msgID, ok := event.Data["message_id"].(string); ok {
					assistantMessageID = msgID
				}
				if text, ok := event.Data["text"].(string); ok {
					assistantMessageText = text
				}
			}

			// Forward all events to client EXCEPT stream.done (we'll send that after audio finishes)
			if event.Type != "stream.done" {
				if err := sse.Event(c.Writer, event.Type, event.Data); err != nil {
					log.Printf("❌ Error writing SSE event: %v", err)
					close(vso.done)
					return err
				}
				flusher()
			}

			// Exit on completion or error
			if event.Type == "stream.done" || event.Type == "error" {
				// Flush ElevenLabs
				if err := session.SendEOS(); err != nil {
					log.Printf("❌ Error sending EOS: %v", err)
				}

				// Wait for audio to finish streaming
				vso.wg.Wait()

				// Send final audio marker
				sse.Event(c.Writer, "audio_chunk", map[string]interface{}{
					"audio":    "",
					"is_final": true,
				})
				flusher()
				
				// Save assistant message to Firestore
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
						log.Printf("❌ Error saving assistant message in voice stream: %v", err)
					} else {
						log.Printf("✅ Saved assistant message in voice stream: %s", assistantMessageID)
					}
				}
				
				// Send stream.done to client
				if event.Type == "stream.done" {
					sse.Event(c.Writer, "stream.done", event.Data)
					flusher()
				}

				return nil
			}

		case <-c.Request.Context().Done():
			log.Printf("🛑 Client disconnected during voice streaming")
			close(vso.done)
			return c.Request.Context().Err()
		}
	}
}
