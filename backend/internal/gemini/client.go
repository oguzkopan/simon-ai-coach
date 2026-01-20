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
	tokens := make(chan string, 10)
	errors := make(chan error, 1)

	go func() {
		defer close(tokens)
		defer close(errors)

		// TODO: Implement actual streaming with genai SDK
		// For now, return a simple response
		response := "This is a placeholder streaming response. "
		for _, char := range response {
			select {
			case <-ctx.Done():
				errors <- ctx.Err()
				return
			case tokens <- string(char):
			}
		}
	}()

	return tokens, errors
}

