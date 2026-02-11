package handlers

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"google.golang.org/genai"

	"simon-backend/internal/agent"
	"simon-backend/internal/config"
	fsClient "simon-backend/internal/firestore"
	geminiClient "simon-backend/internal/gemini"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/models"
	"simon-backend/internal/orchestrator"
	"simon-backend/internal/sse"
)

// SendMessage sends a message and returns immediately (non-streaming)
func SendMessage(fs *fsClient.Client, gm *geminiClient.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		var req models.SendMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Validate session ownership
		sessionDoc, err := fs.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}

		var session models.Session
		if err := sessionDoc.DataTo(&session); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse session"})
			return
		}

		if session.UID != uid {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}

		// Save user message
		userMsg := models.Message{
			ID:          uuid.New().String(),
			Role:        "user",
			ContentText: req.UserText,
			Attachments: req.Attachments,
			CreatedAt:   time.Now(),
		}

		_, err = fs.DB.Collection("sessions").Doc(sessionID).
			Collection("messages").Doc(userMsg.ID).Set(ctx, userMsg)
		if err != nil {
			log.Printf("Error saving user message: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save message"})
			return
		}

		// Update session timestamp
		_, err = fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, []firestore.Update{
			{Path: "updated_at", Value: time.Now()},
		})
		if err != nil {
			log.Printf("Error updating session: %v", err)
		}

		c.JSON(http.StatusOK, userMsg)
	}
}

// StreamChat streams chat responses using SSE with multi-agent orchestration
func StreamChat(fs *fsClient.Client, gm *geminiClient.Client, cfg config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		uid := middleware.GetUID(c)
		sessionID := c.Param("id")

		log.Printf("StreamChat: uid=%s, sessionID=%s", uid, sessionID)

		// Parse request body
		var req models.SendMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}

		// Initialize SSE
		flusher, ok := sse.Init(c.Writer)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "streaming not supported"})
			return
		}
		
		// CRITICAL: Write headers immediately to establish the stream
		// This prevents Gin from buffering the response
		c.Writer.WriteHeaderNow()
		flusher.Flush()

		// Handle audio data if present
		var audioBytes []byte
		var audioAttachment *models.Attachment
		if req.AudioData != "" {
			// Decode audio (use = instead of := to avoid shadowing)
			var err error
			audioBytes, err = base64.StdEncoding.DecodeString(req.AudioData)
			if err != nil {
				log.Printf("Error decoding audio: %v", err)
				sse.Event(c.Writer, "error", map[string]interface{}{
					"code":    "AUDIO_DECODE_ERROR",
					"message": "invalid audio data",
				})
				flusher.Flush()
				return
			}
			log.Printf("📢 Decoded audio data: %d bytes", len(audioBytes))

			// Upload audio to Firebase Storage
			audioURL, storagePath, uploadErr := uploadAudioToStorage(ctx, cfg.ProjectID, uid, sessionID, audioBytes)
			if uploadErr != nil {
				log.Printf("Error uploading audio: %v", uploadErr)
				// Continue anyway - audio will still be processed
			} else {
				audioAttachment = &models.Attachment{
					Type:        "audio",
					StoragePath: storagePath,
					DownloadURL: audioURL,
					MimeType:    "audio/wav",
				}
				log.Printf("✅ Audio uploaded: %s", audioURL)
			}
		}

		// Validate session ownership
		sessionDoc, err := fs.DB.Collection("sessions").Doc(sessionID).Get(ctx)
		if err != nil {
			log.Printf("Error getting session: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "SESSION_NOT_FOUND",
				"message": "session not found",
			})
			flusher.Flush()
			return
		}

		var session models.Session
		if err := sessionDoc.DataTo(&session); err != nil {
			log.Printf("Error parsing session: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "SESSION_PARSE_ERROR",
				"message": "failed to parse session",
			})
			flusher.Flush()
			return
		}

		if session.UID != uid {
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "ACCESS_DENIED",
				"message": "access denied",
			})
			flusher.Flush()
			return
		}

		// Get coach ID and voice config
		coachID := ""
		var coachVoiceConfig *models.VoiceConfig
		var selectedCoachName string
		
		if session.CoachID != nil {
			coachID = *session.CoachID
			selectedCoachName = session.CoachName

			// Fetch coach to get voice configuration if voice-over is enabled
			if req.VoiceOverEnabled {
				log.Printf("🎙️ Voice-over requested for coach: %s", coachID)
				coachDoc, err := fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
				if err != nil {
					log.Printf("⚠️ Failed to fetch coach for voice config: %v", err)
				} else {
					var coach models.Coach
					if err := coachDoc.DataTo(&coach); err != nil {
						log.Printf("⚠️ Failed to parse coach data: %v", err)
					} else {
						log.Printf("🎙️ Coach loaded: has_spec=%v", coach.CoachSpec != nil)
						if coach.CoachSpec != nil && coach.CoachSpec.Voice != nil {
							log.Printf("🎙️ CoachSpec.Voice: %+v", coach.CoachSpec.Voice)
							coachVoiceConfig = coach.CoachSpec.Voice
							log.Printf("🎙️ Using coach-specific voice: ID=%s, Enabled=%v", coachVoiceConfig.VoiceID, coachVoiceConfig.Enabled)
						}
					}
				}
				
				// If no voice config found, use default
				if coachVoiceConfig == nil {
					log.Printf("🎙️ No coach-specific voice config, using default voice")
					coachVoiceConfig = &models.VoiceConfig{
						Enabled:    true,
						VoiceID:    "21m00Tcm4TlvDq8ikWAM", // Rachel - default ElevenLabs voice
						VoiceName:  "Rachel",
						Stability:  0.5,
						Similarity: 0.75,
						Style:      0.0,
						PresetName: "Balanced",
					}
				}
			}
		} else {
			// No coach assigned yet - perform coach selection now
			log.Printf("🔍 Performing coach selection for session: %s", sessionID)
			
			// Send stream.open with coach_selecting flag
			sse.Event(c.Writer, "stream.open", map[string]interface{}{
				"session_id":      sessionID,
				"server_time_iso": time.Now().Format(time.RFC3339),
				"coach_selecting": true,
			})
			flusher.Flush()
			
			// Send processing step: analyzing intent
			sse.Event(c.Writer, "processing.step", map[string]interface{}{
				"step":    "analyzing",
				"message": "Understanding your needs...",
			})
			flusher.Flush()
			
			// Use router agent to select coach
			routerAgent := agent.NewRouter(gm, fs)
			routeResult, err := routerAgent.Route(ctx, uid, req.UserText)
			if err != nil {
				log.Printf("❌ Coach selection failed: %v", err)
				sse.Event(c.Writer, "error", map[string]interface{}{
					"code":    "COACH_SELECTION_ERROR",
					"message": "Failed to select appropriate coach",
				})
				flusher.Flush()
				return
			}
			
			// Send processing step: coach selected
			sse.Event(c.Writer, "processing.step", map[string]interface{}{
				"step":    "matching",
				"message": "Matching you with the right coach...",
			})
			flusher.Flush()
			
			// Update session with selected coach
			if routeResult.CoachID != nil {
				coachID = *routeResult.CoachID
			}
			selectedCoachName = routeResult.CoachName
			
			// Update session in Firestore
			_, err = fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, []firestore.Update{
				{Path: "coach_id", Value: routeResult.CoachID},
				{Path: "coach_name", Value: routeResult.CoachName},
				{Path: "title", Value: routeResult.Title},
				{Path: "updated_at", Value: time.Now()},
			})
			if err != nil {
				log.Printf("⚠️ Failed to update session with coach: %v", err)
			}
			
			// Send coach.selected event
			sse.Event(c.Writer, "coach.selected", map[string]interface{}{
				"coach_id":   coachID,
				"coach_name": selectedCoachName,
			})
			flusher.Flush()
			
			log.Printf("✅ Coach selected: %s (%s)", selectedCoachName, coachID)
		}

		// Save user message first
		userAttachments := req.Attachments
		if audioAttachment != nil {
			userAttachments = append(userAttachments, *audioAttachment)
		}

		userText := req.UserText
		if userText == "" && len(audioBytes) > 0 {
			userText = "🎤 Voice message"
		}

		userMsg := models.Message{
			ID:          uuid.New().String(),
			Role:        "user",
			ContentText: userText,
			Attachments: userAttachments,
			CreatedAt:   time.Now(),
		}

		// Log the message being saved
		log.Printf("💾 Saving user message: id=%s, text=%s, attachments=%d", userMsg.ID, userText, len(userAttachments))
		for i, att := range userAttachments {
			log.Printf("💾 Message attachment %d: type=%s, url=%s", i, att.Type, att.DownloadURL)
		}

		_, err = fs.DB.Collection("sessions").Doc(sessionID).
			Collection("messages").Doc(userMsg.ID).Set(ctx, userMsg)
		if err != nil {
			log.Printf("Error saving user message: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "MESSAGE_SAVE_ERROR",
				"message": "failed to save user message",
			})
			flusher.Flush()
			return
		}

		// Update session timestamp and title (if still "New Session")
		updates := []firestore.Update{
			{Path: "updated_at", Value: time.Now()},
		}

		// If session title is still "New Session", generate a better title from the first message
		if session.Title == "New Session" {
			// Generate title from first 50 characters of the message
			title := req.UserText
			if len(title) > 50 {
				title = title[:50] + "..."
			}
			updates = append(updates, firestore.Update{
				Path:  "title",
				Value: title,
			})
			log.Printf("Updating session title to: %s", title)
		}

		_, err = fs.DB.Collection("sessions").Doc(sessionID).Update(ctx, updates)
		if err != nil {
			log.Printf("Error updating session: %v", err)
		}

		// Create pipeline
		pipeline := orchestrator.NewPipeline(fs, gm)

		// Log audio data being passed to pipeline
		if len(audioBytes) > 0 {
			log.Printf("🎤 Passing %d bytes of audio to pipeline", len(audioBytes))
			log.Printf("🎤 User attachments count: %d", len(userAttachments))
			for i, att := range userAttachments {
				log.Printf("🎤 Attachment %d: type=%s, url=%s", i, att.Type, att.DownloadURL)
			}
		}

		// Execute pipeline - pass userAttachments which includes the audio attachment
		output, err := pipeline.Execute(ctx, orchestrator.PipelineInput{
			SessionID:     sessionID,
			CoachID:       coachID,
			UserMessage:   userText,
			Attachments:   userAttachments, // Use userAttachments which includes audio
			UID:           uid,
			UserTimezone:  req.UserTimezone,
			UserLocalTime: req.UserLocalTime,
			AudioData:     audioBytes, // Pass audio directly to pipeline
		})
		if err != nil {
			log.Printf("Pipeline execution error: %v", err)
			sse.Event(c.Writer, "error", map[string]interface{}{
				"code":    "PIPELINE_ERROR",
				"message": fmt.Sprintf("Pipeline failed: %v", err),
			})
			flusher.Flush()
			return
		}

		// Check if voice-over streaming is enabled
		if req.VoiceOverEnabled && coachVoiceConfig != nil {
			log.Printf("🎙️ Starting voice-over streaming with voice: %s (enabled=%v)", 
				coachVoiceConfig.VoiceID, coachVoiceConfig.Enabled)
			voiceOrchestrator := NewVoiceStreamOrchestrator(cfg)
			if err := voiceOrchestrator.StreamWithVoice(c, fs, output, coachVoiceConfig, flusher.Flush); err != nil {
				log.Printf("❌ Voice streaming error: %v", err)
				// Fall back to regular streaming on error
			} else {
				// Voice streaming completed successfully
				log.Printf("✅ Voice-over streaming completed successfully")
				return
			}
		}

		// Keep-alive ticker (every 15 seconds)
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()

		// Connection timeout (5 minutes)
		timeout := time.NewTimer(5 * time.Minute)
		defer timeout.Stop()

		// Event ID counter
		eventID := 0

		// Track assistant message
		var assistantMessageID string
		var assistantMessageText string

		// Stream events from pipeline
		for {
			select {
			case event, ok := <-output.Stream:
				if !ok {
					// Stream closed normally
					log.Printf("Stream closed: sessionID=%s", sessionID)

					// Save assistant message if we have one
					if assistantMessageText != "" {
						assistantMsg := models.Message{
							ID:          assistantMessageID,
							Role:        "assistant",
							ContentText: assistantMessageText,
							Attachments: nil,
							CreatedAt:   time.Now(),
						}

						_, err := fs.DB.Collection("sessions").Doc(sessionID).
							Collection("messages").Doc(assistantMsg.ID).Set(context.Background(), assistantMsg)
						if err != nil {
							log.Printf("Error saving assistant message: %v", err)
						} else {
							log.Printf("Saved assistant message: %s", assistantMessageID)
						}
					}

					return
				}

				// Increment event ID
				eventID++

				// Debug log the event
				log.Printf("SSE Event #%d: type=%s, data=%+v", eventID, event.Type, event.Data)

				// Track message content for saving
				if event.Type == "message.delta" {
					if delta, ok := event.Data["delta"].(string); ok {
						assistantMessageText += delta
					}
				} else if event.Type == "message.final" {
					if msgID, ok := event.Data["message_id"].(string); ok {
						assistantMessageID = msgID
					}
					if text, ok := event.Data["text"].(string); ok {
						assistantMessageText = text
					}
				}

				// Write SSE event with ID
				if err := sse.EventWithID(c.Writer, fmt.Sprintf("%d", eventID), event.Type, event.Data); err != nil {
					log.Printf("Error writing SSE event: %v", err)
					return
				}
				
				// CRITICAL: Smart flushing strategy
				// - message.delta: ALWAYS flush immediately for real-time text streaming
				// - message.final: ALWAYS flush immediately to complete the message
				// - tool.request: Flush immediately so UI can show "Creating event..."
				// - tool.status: Flush immediately so UI can show "Event created ✓"
				// - Other events: Flush immediately for responsiveness
				//
				// Note: Gemini sends tool calls AFTER text generation completes,
				// so text streaming is never blocked by tool execution
				flusher.Flush()

				// Exit on completion or error
				if event.Type == "stream.done" || event.Type == "error" {
					log.Printf("Stream completed: sessionID=%s, type=%s", sessionID, event.Type)

					// Save assistant message before exiting
					if assistantMessageText != "" {
						assistantMsg := models.Message{
							ID:          assistantMessageID,
							Role:        "assistant",
							ContentText: assistantMessageText,
							Attachments: nil,
							CreatedAt:   time.Now(),
						}

						_, err := fs.DB.Collection("sessions").Doc(sessionID).
							Collection("messages").Doc(assistantMsg.ID).Set(context.Background(), assistantMsg)
						if err != nil {
							log.Printf("Error saving assistant message: %v", err)
						} else {
							log.Printf("Saved assistant message: %s", assistantMessageID)
						}
					}

					return
				}

			case <-ticker.C:
				// Send keep-alive comment
				if err := sse.KeepAlive(c.Writer); err != nil {
					log.Printf("Error sending keep-alive: %v", err)
					return
				}
				flusher.Flush()

			case <-timeout.C:
				// Connection timeout
				log.Printf("Connection timeout: sessionID=%s", sessionID)
				sse.Event(c.Writer, "error", map[string]interface{}{
					"code":    "TIMEOUT",
					"message": "Connection timeout after 5 minutes",
				})
				flusher.Flush()
				return

			case <-ctx.Done():
				// Client disconnected
				log.Printf("Client disconnected: sessionID=%s", sessionID)
				return
			}
		}
	}
}

// Helper functions

func getConversationHistory(ctx context.Context, fs *fsClient.Client, sessionID string) ([]models.Message, error) {
	iter := fs.DB.Collection("sessions").Doc(sessionID).
		Collection("messages").
		OrderBy("created_at", firestore.Asc).
		Documents(ctx)
	defer iter.Stop()

	var messages []models.Message
	for {
		doc, err := iter.Next()
		if err != nil {
			break
		}

		var msg models.Message
		if err := doc.DataTo(&msg); err != nil {
			continue
		}
		messages = append(messages, msg)
	}

	return messages, nil
}

func buildSystemPrompt(blueprint map[string]interface{}) string {
	// Default system prompt
	prompt := `You are a minimalist AI coach. Your style:
- Ask ONE clarifying question first
- Give 3-step answers by default
- Offer to create a system when useful
- Be calm, direct, and actionable

Never give medical, legal, or financial advice. Suggest professional help when appropriate.`

	// TODO: Customize based on blueprint (Week 2)
	_ = blueprint

	return prompt
}

func buildHistoryPrompt(history []models.Message) string {
	if len(history) == 0 {
		return ""
	}

	var prompt string
	for _, msg := range history {
		role := msg.Role
		if role == "assistant" {
			role = "Assistant"
		} else {
			role = "User"
		}
		prompt += fmt.Sprintf("%s: %s\n\n", role, msg.ContentText)
	}
	return prompt
}

func buildGeminiContents(systemPrompt string, history []models.Message) []*genai.Content {
	contents := []*genai.Content{
		{
			Role: "user",
			Parts: []*genai.Part{
				{Text: systemPrompt},
			},
		},
	}

	for _, msg := range history {
		role := msg.Role
		if role == "assistant" {
			role = "model"
		}

		contents = append(contents, &genai.Content{
			Role: role,
			Parts: []*genai.Part{
				{Text: msg.ContentText},
			},
		})
	}

	return contents
}

func extractToken(resp *genai.GenerateContentResponse) string {
	if len(resp.Candidates) > 0 &&
		resp.Candidates[0].Content != nil &&
		len(resp.Candidates[0].Content.Parts) > 0 {
		return resp.Candidates[0].Content.Parts[0].Text
	}
	return ""
}

// uploadAudioToStorage uploads audio to Firebase Storage and returns the public URL
func uploadAudioToStorage(ctx context.Context, projectID, uid, sessionID string, audioData []byte) (string, string, error) {
	// Create storage client
	storageClient, err := storage.NewClient(ctx)
	if err != nil {
		return "", "", fmt.Errorf("failed to create storage client: %w", err)
	}
	defer storageClient.Close()

	// Add WAV header to raw PCM data
	// Gemini expects proper WAV format, not raw PCM
	wavData := addWAVHeader(audioData, 16000, 1, 16) // 16kHz, mono, 16-bit
	log.Printf("📢 Added WAV header: original size=%d bytes, with header=%d bytes", len(audioData), len(wavData))

	// Generate filename
	filename := fmt.Sprintf("voice_messages/%s/%s/%s.wav", uid, sessionID, uuid.New().String())
	
	// Get bucket
	bucketName := fmt.Sprintf("%s.firebasestorage.app", projectID)
	log.Printf("Uploading audio to bucket: %s, filename: %s", bucketName, filename)
	
	bucket := storageClient.Bucket(bucketName)
	obj := bucket.Object(filename)
	
	// Upload with metadata
	writer := obj.NewWriter(ctx)
	writer.ContentType = "audio/wav"
	writer.Metadata = map[string]string{
		"uid":        uid,
		"session_id": sessionID,
		"type":       "voice_message",
	}
	
	log.Printf("📤 Uploading audio: bucket=%s, path=%s, size=%d bytes", bucketName, filename, len(wavData))
	
	if _, err := writer.Write(wavData); err != nil {
		writer.Close()
		return "", "", fmt.Errorf("failed to write audio: %w", err)
	}
	
	if err := writer.Close(); err != nil {
		return "", "", fmt.Errorf("failed to close writer: %w", err)
	}
	
	// Set metadata to make file publicly accessible
	// This works better than ACL for Firebase Storage
	attrs := storage.ObjectAttrsToUpdate{
		Metadata: map[string]string{
			"firebaseStorageDownloadTokens": uuid.New().String(), // Generate download token
		},
	}
	
	objAttrs, err := obj.Update(ctx, attrs)
	if err != nil {
		log.Printf("Warning: failed to set download token: %v", err)
		// Continue anyway - try without token
	}
	
	// Try to make object publicly readable via ACL (may not work depending on bucket settings)
	acl := obj.ACL()
	if err := acl.Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		log.Printf("Warning: failed to set ACL: %v", err)
		// This is expected if uniform bucket-level access is enabled
	}
	
	// Return public URL with download token if available
	var publicURL string
	if objAttrs != nil && objAttrs.Metadata != nil {
		if token, ok := objAttrs.Metadata["firebaseStorageDownloadTokens"]; ok {
			publicURL = fmt.Sprintf("https://firebasestorage.googleapis.com/v0/b/%s/o/%s?alt=media&token=%s", 
				bucketName, 
				strings.ReplaceAll(filename, "/", "%2F"),
				token,
			)
			log.Printf("✅ Generated public URL with token: %s", publicURL)
		}
	}
	
	// Fallback to URL without token
	if publicURL == "" {
		publicURL = fmt.Sprintf("https://firebasestorage.googleapis.com/v0/b/%s/o/%s?alt=media", 
			bucketName, 
			strings.ReplaceAll(filename, "/", "%2F"),
		)
		log.Printf("⚠️ Generated public URL without token (may require Firebase Storage rules): %s", publicURL)
	}
	
	return publicURL, filename, nil
}

// addWAVHeader adds a WAV file header to raw PCM data
func addWAVHeader(pcmData []byte, sampleRate, channels, bitsPerSample int) []byte {
	dataSize := len(pcmData)
	byteRate := sampleRate * channels * bitsPerSample / 8
	blockAlign := channels * bitsPerSample / 8
	
	header := make([]byte, 44)
	
	// RIFF header
	copy(header[0:4], "RIFF")
	binary.LittleEndian.PutUint32(header[4:8], uint32(36+dataSize))
	copy(header[8:12], "WAVE")
	
	// fmt chunk
	copy(header[12:16], "fmt ")
	binary.LittleEndian.PutUint32(header[16:20], 16) // fmt chunk size
	binary.LittleEndian.PutUint16(header[20:22], 1)  // audio format (1 = PCM)
	binary.LittleEndian.PutUint16(header[22:24], uint16(channels))
	binary.LittleEndian.PutUint32(header[24:28], uint32(sampleRate))
	binary.LittleEndian.PutUint32(header[28:32], uint32(byteRate))
	binary.LittleEndian.PutUint16(header[32:34], uint16(blockAlign))
	binary.LittleEndian.PutUint16(header[34:36], uint16(bitsPerSample))
	
	// data chunk
	copy(header[36:40], "data")
	binary.LittleEndian.PutUint32(header[40:44], uint32(dataSize))
	
	// Combine header and data
	wavData := append(header, pcmData...)
	return wavData
}
