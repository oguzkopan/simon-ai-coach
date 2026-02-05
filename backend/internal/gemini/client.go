package gemini

import (
	"context"
	"fmt"
	"log"
	"time"

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
		Backend:     genai.BackendVertexAI,
		Project:     project,
		Location:    location,
		HTTPOptions: genai.HTTPOptions{APIVersion: "v1"},
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
func (c *Client) GenerateContentStreamWithHistory(ctx context.Context, systemPrompt string, history []interface{}, currentParts []*genai.Part) (<-chan string, <-chan error) {
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
			MaxOutputTokens: 4096,
			ThinkingConfig: &genai.ThinkingConfig{
				ThinkingLevel: genai.ThinkingLevelMinimal,
			},
			SystemInstruction: &genai.Content{
				Parts: []*genai.Part{{Text: systemPrompt}},
			},
			SafetySettings: []*genai.SafetySetting{
				{
					Category:  genai.HarmCategoryHarassment,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategoryHateSpeech,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategorySexuallyExplicit,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategoryDangerousContent,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
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

		// Add current user message parts
		contents = append(contents, &genai.Content{
			Role:  "user",
			Parts: currentParts,
		})

		// Stream responses using the modern API pattern
		for resp, err := range c.Raw.Models.GenerateContentStream(ctx, c.Model, contents, config) {
			if err != nil {
				errors <- fmt.Errorf("gemini stream error: %w", err)
				return
			}

			// Extract text from response using resp.Text() helper
			// Note: resp.Text() returns the text parts of this specific chunk in the stream
			if text := resp.Text(); text != "" {
				select {
				case <-ctx.Done():
					errors <- ctx.Err()
					return
				case tokens <- text:
				}
			}
		}
	}()

	return tokens, errors
}

// ToolCallOrText represents either a tool call or text from Gemini
type ToolCallOrText struct {
	IsToolCall bool
	Text       string
	ToolCall   *ToolCall
}

// ToolCall represents a function call from Gemini
type ToolCall struct {
	Name      string
	Arguments map[string]interface{}
}

// GenerateContentStreamWithTools streams content with function calling support
func (c *Client) GenerateContentStreamWithTools(
	ctx context.Context,
	systemPrompt string,
	history []interface{},
	currentParts []*genai.Part,
	tools []*genai.Tool,
) (<-chan ToolCallOrText, <-chan error) {
	results := make(chan ToolCallOrText, 100)
	errors := make(chan error, 1)

	go func() {
		defer close(results)
		defer close(errors)

		// Configure generation parameters
		temperature := float32(0.0)
		topP := float32(0.95)
		topK := float32(40)

		config := &genai.GenerateContentConfig{
			Temperature:     &temperature,
			TopP:            &topP,
			TopK:            &topK,
			MaxOutputTokens: 4096,
			ThinkingConfig: &genai.ThinkingConfig{
				ThinkingLevel: genai.ThinkingLevelMinimal,
			},
			SystemInstruction: &genai.Content{
				Parts: []*genai.Part{{Text: systemPrompt}},
			},
			Tools: tools,
			SafetySettings: []*genai.SafetySetting{
				{
					Category:  genai.HarmCategoryHarassment,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategoryHateSpeech,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategorySexuallyExplicit,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
				{
					Category:  genai.HarmCategoryDangerousContent,
					Threshold: genai.HarmBlockThresholdBlockNone,
				},
			},
		}

		// Build conversation history
		var contents []*genai.Content
		for _, msg := range history {
			if msgMap, ok := msg.(map[string]interface{}); ok {
				role := "user"
				if r, ok := msgMap["role"].(string); ok {
					if r == "assistant" {
						role = "model"
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

		// Add current user message parts
		contents = append(contents, &genai.Content{
			Role:  "user",
			Parts: currentParts,
		})

		// Stream responses
		for resp, err := range c.Raw.Models.GenerateContentStream(ctx, c.Model, contents, config) {
			if err != nil {
				errors <- fmt.Errorf("gemini stream error: %w", err)
				return
			}

			// 1. Send text as it arrives (resp.Text() returns the text in this chunk)
			if text := resp.Text(); text != "" {
				select {
				case <-ctx.Done():
					errors <- ctx.Err()
					return
				case results <- ToolCallOrText{
					IsToolCall: false,
					Text:       text,
				}:
				}
			}

			// 2. Check for function calls in this chunk
			if len(resp.Candidates) > 0 && resp.Candidates[0].Content != nil {
				for _, part := range resp.Candidates[0].Content.Parts {
					if part.FunctionCall != nil {
						toolCall := &ToolCall{
							Name:      part.FunctionCall.Name,
							Arguments: part.FunctionCall.Args,
						}

						select {
						case <-ctx.Done():
							errors <- ctx.Err()
							return
						case results <- ToolCallOrText{
							IsToolCall: true,
							ToolCall:   toolCall,
						}:
						}
					}
				}
			}
		}
	}()

	return results, errors
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
			MaxOutputTokens: 4096,
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

// GenerateImage generates an image using Vertex AI Gemini Flash Image
func (c *Client) GenerateImage(ctx context.Context, prompt string) ([]byte, string, error) {
	// Use Gemini 2.5 Flash Image model - has higher quota limits than Pro
	modelID := "gemini-2.5-flash-image"
	
	log.Printf("GenerateImage: Starting with Vertex AI model=%s", modelID)
	
	// Create a context with a longer timeout for image generation (90 seconds)
	ctx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	
	// Configuration for image generation
	temperature := float32(1.0)
	config := &genai.GenerateContentConfig{
		Temperature: &temperature,
		// Request both TEXT and IMAGE modalities
		ResponseModalities: []string{"TEXT", "IMAGE"},
		// Configure Image specific parameters
		ImageConfig: &genai.ImageConfig{
			AspectRatio: "1:1", // Standard square
			ImageSize:   "1K",  // 1024x1024 resolution
		},
	}
	
	log.Printf("GenerateImage: Calling Vertex AI Gemini API with ImageConfig (AspectRatio=1:1, ImageSize=1K)...")
	
	// Generate content with the image prompt using Vertex AI client
	result, err := c.Raw.Models.GenerateContent(ctx, modelID, genai.Text(prompt), config)
	if err != nil {
		log.Printf("GenerateImage: API call failed: %v", err)
		return nil, "", fmt.Errorf("failed to generate image: %w", err)
	}
	
	log.Printf("GenerateImage: API call succeeded, processing response...")
	
	// Extract the generated image from the response
	for i, candidate := range result.Candidates {
		log.Printf("GenerateImage: Processing candidate %d with %d parts", i, len(candidate.Content.Parts))
		for j, part := range candidate.Content.Parts {
			if part.InlineData != nil {
				log.Printf("GenerateImage: Found inline data at candidate=%d, part=%d, size=%d bytes, mime=%s", 
					i, j, len(part.InlineData.Data), part.InlineData.MIMEType)
				// Return the image data and MIME type
				return part.InlineData.Data, part.InlineData.MIMEType, nil
			}
		}
	}
	
	log.Printf("GenerateImage: No image data found in response")
	return nil, "", fmt.Errorf("no image data found in response")
}
