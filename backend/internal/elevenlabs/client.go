package elevenlabs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

const (
	BaseURL           = "https://api.elevenlabs.io/v1"
	WebSocketURL      = "wss://api.elevenlabs.io/v1"
	LatestTurboModel  = "eleven_turbo_v2_5"
	LatestFlashModel  = "eleven_flash_v2_5"
)

// Client handles ElevenLabs API interactions
type Client struct {
	apiKey     string
	httpClient *http.Client
}

// NewClient creates a new ElevenLabs client
func NewClient(apiKey string) *Client {
	return &Client{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Voice represents an ElevenLabs voice
type Voice struct {
	VoiceID     string            `json:"voice_id"`
	Name        string            `json:"name"`
	Category    string            `json:"category"`
	Description string            `json:"description,omitempty"`
	PreviewURL  string            `json:"preview_url,omitempty"`
	Labels      map[string]string `json:"labels,omitempty"`
	Settings    *VoiceSettings    `json:"settings,omitempty"`
}

// VoiceSettings represents voice configuration
type VoiceSettings struct {
	Stability       float64 `json:"stability"`
	SimilarityBoost float64 `json:"similarity_boost"`
	Style           float64 `json:"style,omitempty"`
	UseSpeakerBoost bool    `json:"use_speaker_boost,omitempty"`
}

// VoicesResponse represents the API response for listing voices
type VoicesResponse struct {
	Voices []Voice `json:"voices"`
}

// GetVoices fetches all available voices
func (c *Client) GetVoices() ([]Voice, error) {
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/voices", BaseURL), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("xi-api-key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch voices: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}

	var result VoicesResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return result.Voices, nil
}

// GetVoice fetches a specific voice by ID
func (c *Client) GetVoice(voiceID string) (*Voice, error) {
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/voices/%s", BaseURL, voiceID), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("xi-api-key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch voice: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}

	var voice Voice
	if err := json.NewDecoder(resp.Body).Decode(&voice); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &voice, nil
}

// TextToSpeechRequest represents a TTS request
type TextToSpeechRequest struct {
	Text          string         `json:"text"`
	ModelID       string         `json:"model_id"`
	VoiceSettings *VoiceSettings `json:"voice_settings,omitempty"`
}

// TextToSpeech converts text to speech (non-streaming)
func (c *Client) TextToSpeech(voiceID string, text string, settings *VoiceSettings) ([]byte, error) {
	if settings == nil {
		settings = &VoiceSettings{
			Stability:       0.5,
			SimilarityBoost: 0.75,
		}
	}

	reqBody := TextToSpeechRequest{
		Text:          text,
		ModelID:       LatestTurboModel,
		VoiceSettings: settings,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/text-to-speech/%s", BaseURL, voiceID), bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("xi-api-key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "audio/mpeg")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to generate speech: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}

	audioData, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read audio data: %w", err)
	}

	return audioData, nil
}

// StreamingSession represents a WebSocket streaming session
type StreamingSession struct {
	conn          *websocket.Conn
	voiceID       string
	modelID       string
	voiceSettings *VoiceSettings
	AudioChan     chan []byte
	ErrorChan     chan error
	done          chan struct{}
}

// NewStreamingSession creates a new streaming TTS session
func (c *Client) NewStreamingSession(voiceID string, settings *VoiceSettings) (*StreamingSession, error) {
	if settings == nil {
		settings = &VoiceSettings{
			Stability:       0.5,
			SimilarityBoost: 0.8,
		}
	}

	url := fmt.Sprintf("%s/text-to-speech/%s/stream-input?model_id=%s", 
		WebSocketURL, voiceID, LatestTurboModel)

	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to WebSocket: %w", err)
	}

	session := &StreamingSession{
		conn:          conn,
		voiceID:       voiceID,
		modelID:       LatestTurboModel,
		voiceSettings: settings,
		AudioChan:     make(chan []byte, 100),
		ErrorChan:     make(chan error, 10),
		done:          make(chan struct{}),
	}

	// Send initial configuration with API key
	initMsg := map[string]interface{}{
		"text":       " ", // Start with empty space to keep connection alive
		"xi_api_key": c.apiKey,
		"voice_settings": map[string]interface{}{
			"stability":        settings.Stability,
			"similarity_boost": settings.SimilarityBoost,
		},
		"generation_config": map[string]interface{}{
			"chunk_length_schedule": []int{50, 120, 160, 250}, // Lower first threshold for faster response
		},
	}

	if err := conn.WriteJSON(initMsg); err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to send init message: %w", err)
	}

	// Start reading audio chunks
	go session.readLoop()

	return session, nil
}

// SendText sends text to be converted to speech
func (s *StreamingSession) SendText(text string) error {
	msg := map[string]interface{}{
		"text": text,
	}
	return s.conn.WriteJSON(msg)
}

// SendEOS sends end-of-stream signal with flush
func (s *StreamingSession) SendEOS() error {
	msg := map[string]interface{}{
		"text":  "",
		"flush": true, // Flush remaining audio
	}
	return s.conn.WriteJSON(msg)
}

// readLoop reads audio chunks from WebSocket
func (s *StreamingSession) readLoop() {
	defer close(s.AudioChan)
	defer close(s.ErrorChan)

	for {
		select {
		case <-s.done:
			return
		default:
			var response map[string]interface{}
			err := s.conn.ReadJSON(&response)
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					s.ErrorChan <- fmt.Errorf("WebSocket error: %w", err)
				}
				return
			}

			// Check for audio data (base64 encoded)
			if audioBase64, ok := response["audio"].(string); ok && audioBase64 != "" {
				// Send the base64 string as-is (client will decode it)
				s.AudioChan <- []byte(audioBase64)
			}

			// Check for errors
			if errMsg, ok := response["error"].(string); ok {
				s.ErrorChan <- fmt.Errorf("API error: %s", errMsg)
			}

			// Check for completion
			if isFinal, ok := response["isFinal"].(bool); ok && isFinal {
				return
			}
		}
	}
}

// Close closes the streaming session
func (s *StreamingSession) Close() error {
	close(s.done)
	return s.conn.Close()
}

// VoicePreset represents common voice presets
type VoicePreset struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Settings    VoiceSettings  `json:"settings"`
}

// GetVoicePresets returns common voice presets
func GetVoicePresets() []VoicePreset {
	return []VoicePreset{
		{
			Name:        "Balanced",
			Description: "Balanced stability and expressiveness",
			Settings: VoiceSettings{
				Stability:       0.5,
				SimilarityBoost: 0.75,
			},
		},
		{
			Name:        "Stable",
			Description: "More consistent, less variation",
			Settings: VoiceSettings{
				Stability:       0.75,
				SimilarityBoost: 0.5,
			},
		},
		{
			Name:        "Expressive",
			Description: "More dynamic and varied",
			Settings: VoiceSettings{
				Stability:       0.25,
				SimilarityBoost: 0.9,
			},
		},
		{
			Name:        "Clear",
			Description: "Clear and articulate",
			Settings: VoiceSettings{
				Stability:       0.6,
				SimilarityBoost: 0.8,
			},
		},
	}
}
