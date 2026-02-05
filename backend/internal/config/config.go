package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Port                       string
	ProjectID                  string
	Location                   string
	GeminiModelID              string
	GeminiModelIDPro           string
	GeminiMaxTokens            int
	GeminiTemperature          float64
	ElevenLabsAPIKey           string
	RevenueCatWebhookSecret    string
	FreeTierMomentsPerDay      int
	FreeTierMessagesPerSession int
	ProTierMessagesPerSession  int
}

func Load() (Config, error) {
	cfg := Config{
		Port:                       getEnv("PORT", "8080"),
		ProjectID:                  getEnv("GCP_PROJECT", ""),
		Location:                   getEnv("GCP_LOCATION", "us-central1"),
		GeminiModelID:              getEnv("GEMINI_MODEL_ID", "gemini-3-flash-preview"),
		GeminiModelIDPro:           getEnv("GEMINI_MODEL_ID_PRO", "gemini-3-flash-preview"),
		GeminiMaxTokens:            getEnvInt("GEMINI_MAX_TOKENS", 8192),
		GeminiTemperature:          getEnvFloat("GEMINI_TEMPERATURE", 0.7),
		ElevenLabsAPIKey:           getEnv("ELEVENLABS_API_KEY", ""),
		RevenueCatWebhookSecret:    getEnv("REVENUECAT_WEBHOOK_SECRET", ""),
		FreeTierMomentsPerDay:      getEnvInt("FREE_TIER_MOMENTS_PER_DAY", 3),
		FreeTierMessagesPerSession: getEnvInt("FREE_TIER_MESSAGES_PER_SESSION", 10),
		ProTierMessagesPerSession:  getEnvInt("PRO_TIER_MESSAGES_PER_SESSION", 100),
	}

	if cfg.ProjectID == "" {
		return cfg, fmt.Errorf("GCP_PROJECT is required")
	}

	// ElevenLabs is optional for now
	if cfg.ElevenLabsAPIKey == "" {
		fmt.Println("Warning: ELEVENLABS_API_KEY not set - voice features will be disabled")
	}

	return cfg, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatVal, err := strconv.ParseFloat(value, 64); err == nil {
			return floatVal
		}
	}
	return defaultValue
}
