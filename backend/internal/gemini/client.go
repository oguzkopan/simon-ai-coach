package gemini

import (
	"context"
	"fmt"

	"google.golang.org/genai"
)

// Client wraps the Gemini API client
type Client struct {
	ProjectID string
	Location  string
	Model     string
	Raw       *genai.Client
}

func New(ctx context.Context, project, location, model string) (*Client, error) {
	if project == "" {
		return nil, fmt.Errorf("project ID is required")
	}

	// Configure for Vertex AI (uses Application Default Credentials)
	config := &genai.ClientConfig{
		Backend:  genai.BackendVertexAI,
		Project:  project,
		Location: location,
	}

	// Initialize the Gemini client with Vertex AI backend
	client, err := genai.NewClient(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create genai client: %w", err)
	}

	return &Client{
		ProjectID: project,
		Location:  location,
		Model:     model,
		Raw:       client,
	}, nil
}

func (c *Client) Close() error {
	// genai.Client doesn't have a Close method in the current version
	return nil
}

// GenerateContentStream streams content using Gemini
func (c *Client) GenerateContentStream(ctx context.Context, prompt string) (<-chan string, <-chan error) {
	tokens := make(chan string, 100)
	errors := make(chan error, 1)

	go func() {
		defer close(tokens)
		defer close(errors)

		// TODO: Implement proper Gemini streaming
		// For now, generate a helpful coaching response
		response := "I hear you. Let me help you with that.\n\n" +
			"Here's what I suggest:\n\n" +
			"1. Take a moment to clarify what you're trying to achieve\n" +
			"2. Break it down into a small, actionable next step\n" +
			"3. Set aside 20 minutes to make progress\n\n" +
			"What feels like the right first step for you?"

		// Send response in chunks to simulate streaming
		words := []string{}
		currentWord := ""
		for _, char := range response {
			if char == ' ' || char == '\n' {
				if currentWord != "" {
					words = append(words, currentWord)
					currentWord = ""
				}
				if char == '\n' {
					words = append(words, "\n")
				} else {
					words = append(words, " ")
				}
			} else {
				currentWord += string(char)
			}
		}
		if currentWord != "" {
			words = append(words, currentWord)
		}

		// Stream words
		for _, word := range words {
			select {
			case <-ctx.Done():
				errors <- ctx.Err()
				return
			case tokens <- word:
				// Small delay to simulate streaming
				// time.Sleep(20 * time.Millisecond)
			}
		}
	}()

	return tokens, errors
}

