package gemini

import (
	"context"
	"fmt"
	"strings"

	"google.golang.org/genai"
)

// GenerateContent generates content from Gemini with a system and user prompt
func (c *Client) GenerateContent(ctx context.Context, systemPrompt, userPrompt string) (string, error) {
	// Combine system and user prompts
	fullPrompt := systemPrompt + "\n\n" + userPrompt

	contents := []*genai.Content{
		{
			Role: "user",
			Parts: []*genai.Part{
				{Text: fullPrompt},
			},
		},
	}

	config := &genai.GenerateContentConfig{
		Temperature:      floatPtr(0.7),
		ResponseMIMEType: "text/plain",
	}

	resp, err := c.Raw.Models.GenerateContent(ctx, c.Model, contents, config)
	if err != nil {
		return "", fmt.Errorf("gemini generate content failed: %w", err)
	}

	// Extract text from response
	if len(resp.Candidates) == 0 {
		return "", fmt.Errorf("no candidates in response")
	}

	candidate := resp.Candidates[0]
	if candidate.Content == nil || len(candidate.Content.Parts) == 0 {
		return "", fmt.Errorf("no content in candidate")
	}

	var result strings.Builder
	for _, part := range candidate.Content.Parts {
		if part.Text != "" {
			result.WriteString(part.Text)
		}
	}

	return result.String(), nil
}

func floatPtr(f float32) *float32 {
	return &f
}

