package config

import (
	"os"
	"strconv"
)

type Config struct {
	// Server
	Port string

	// GCP
	ProjectID string
	Location  string

	// Gemini
	ModelID     string
	ModelIDPro  string
	MaxTokens   int
	Temperature float32

	// Rate Limiting
	FreeTierMomentsPerDay      int
	FreeTierMessagesPerSession int
	ProTierMessagesPerSession  int

	// RevenueCat
	RevenueCatAPIKey string
}

func Load() Config {
	c := Config{
		Port:      getEnv("PORT", "8080"),
		ProjectID: getEnv("GCP_PROJECT", ""),
		Location:  getEnv("GCP_LOCATION", "us-central1"),

		ModelID:     getEnv("GEMINI_MODEL_ID", "gemini-2.0-flash-exp"),
		ModelIDPro:  getEnv("GEMINI_MODEL_ID_PRO", "gemini-2.0-flash-exp"),
		MaxTokens:   getEnvInt("GEMINI_MAX_TOKENS", 2048),
		Temperature: getEnvFloat("GEMINI_TEMPERATURE", 0.7),

		FreeTierMomentsPerDay:      getEnvInt("FREE_TIER_MOMENTS_PER_DAY", 3),
		FreeTierMessagesPerSession: getEnvInt("FREE_TIER_MESSAGES_PER_SESSION", 10),
		ProTierMessagesPerSession:  getEnvInt("PRO_TIER_MESSAGES_PER_SESSION", 100),

		RevenueCatAPIKey: getEnv("REVENUECAT_API_KEY", ""),
	}

	return c
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvFloat(key string, fallback float32) float32 {
	if value := os.Getenv(key); value != "" {
		if f, err := strconv.ParseFloat(value, 32); err == nil {
			return float32(f)
		}
	}
	return fallback
}
