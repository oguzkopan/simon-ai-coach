package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"simon-backend/internal/config"
	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	router "simon-backend/internal/http"
)

func main() {
	ctx := context.Background()

	// Load configuration
	cfg := config.Load()
	log.Printf("Starting Simon API on port %s", cfg.Port)
	log.Printf("Project: %s, Location: %s", cfg.ProjectID, cfg.Location)

	// Initialize Firestore
	fs, err := firestore.New(ctx, cfg.ProjectID)
	if err != nil {
		log.Fatalf("Failed to initialize Firestore: %v", err)
	}
	defer fs.Close()
	log.Println("Firestore initialized successfully")

	// Initialize Gemini
	gm, err := gemini.New(ctx, cfg.ProjectID, cfg.Location, cfg.ModelID)
	if err != nil {
		log.Fatalf("Failed to initialize Gemini: %v", err)
	}
	defer gm.Close()
	log.Printf("Gemini initialized successfully (model: %s)", cfg.ModelID)

	// Initialize router
	r, err := router.New(cfg, fs, gm)
	if err != nil {
		log.Fatalf("Failed to initialize router: %v", err)
	}

	// Create server
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second, // Longer for SSE streaming
		IdleTimeout:  120 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Server listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
