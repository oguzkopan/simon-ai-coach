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

// GenerateContentStreamWithHistory streams content using Gemini with conversation history
func (c *Client) GenerateContentStreamWithHistory(ctx context.Context, systemPrompt string, history []interface{}, currentMessage string) (<-chan string, <-chan error) {
	tokens := make(chan string, 100)
	errors := make(chan error, 1)

	go func() {
		defer close(tokens)
		defer close(errors)

		// Configure generation parameters
		temperature := float32(0.7)
		topP := float32(0.95)
		topK := float32(40)
		
		config := &genai.GenerateContentConfig{
			Temperature:     &temperature,
			TopP:            &topP,
			TopK:            &topK,
			MaxOutputTokens: 2048,
			SystemInstruction: &genai.Content{
				Parts: []*genai.Part{{Text: systemPrompt}},
			},
		}

		// Build conversation history as genai.Content
		var contents []*genai.Content
		for _, msg := range history {
			if msgMap, ok := msg.(map[string]interface{}); ok {
				role := "user"
				if r, ok := msgMap["role"].(string); ok {
					if r == "assistant" {
						role = "model" // Gemini uses "model" instead of "assistant"
					}
				}
				
				text := ""
				if t, ok := msgMap["content_text"].(string); ok {
					text = t
				}
				
				if text != "" {
					contents = append(contents, &genai.Content{
						Role:  role,
						Parts: []*genai.Part{{Text: text}},
					})
				}
			}
		}
		
		// Add current user message
		contents = append(contents, &genai.Content{
			Role:  "user",
			Parts: []*genai.Part{{Text: currentMessage}},
		})

		// Stream responses using the modern API pattern
		for resp, err := range c.Raw.Models.GenerateContentStream(ctx, c.Model, contents, config) {
			if err != nil {
				errors <- fmt.Errorf("gemini stream error: %w", err)
				return
			}

			// Extract text from response using resp.Text() helper
			text := resp.Text()
			if text != "" {
				select {
				case <-ctx.Done():
					errors <- ctx.Err()
					return
				case tokens <- text:
					// Token sent successfully
				}
			}
		}
	}()

	return tokens, errors
}

// GenerateContentStream streams content using Gemini (legacy single-prompt method)
func (c *Client) GenerateContentStream(ctx context.Context, prompt string) (<-chan string, <-chan error) {
	tokens := make(chan string, 100)
	errors := make(chan error, 1)

	go func() {
		defer close(tokens)
		defer close(errors)

		// Configure generation parameters
		temperature := float32(0.7)
		topP := float32(0.95)
		topK := float32(40)
		
		config := &genai.GenerateContentConfig{
			Temperature:     &temperature,
			TopP:            &topP,
			TopK:            &topK,
			MaxOutputTokens: 2048,
		}

		// Stream responses using the modern API pattern
		// genai.Text() is the helper function for creating text content
		for resp, err := range c.Raw.Models.GenerateContentStream(ctx, c.Model, genai.Text(prompt), config) {
			if err != nil {
				errors <- fmt.Errorf("gemini stream error: %w", err)
				return
			}

			// Extract text from response using resp.Text() helper
			text := resp.Text()
			if text != "" {
				select {
				case <-ctx.Done():
					errors <- ctx.Err()
					return
				case tokens <- text:
					// Token sent successfully
				}
			}
		}
	}()

	return tokens, errors
}

