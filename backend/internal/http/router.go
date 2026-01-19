package router

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"simon-backend/internal/config"
	"simon-backend/internal/firestore"
	"simon-backend/internal/gemini"
	"simon-backend/internal/http/handlers"
	"simon-backend/internal/http/middleware"
	"simon-backend/internal/logger"
)

func New(cfg config.Config, fs *firestore.Client, gm *gemini.Client) (*gin.Engine, error) {
	// Set Gin mode based on environment
	if cfg.Port == "8080" {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Recovery())
	
	// Structured logging
	log := logger.New()
	r.Use(logger.RequestIDMiddleware())
	r.Use(logger.LoggingMiddleware(log))
	
	r.Use(middleware.CORS())

	// Public routes
	r.GET("/healthz", handlers.Health)

	// Initialize auth middleware
	authMW, err := middleware.NewFirebaseAuth()
	if err != nil {
		return nil, err
	}

	// Initialize rate limiter
	// 100 requests per minute per user
	rateLimiter := middleware.NewRateLimiter(100, time.Minute)

	// Protected routes
	v1 := r.Group("/v1")
	v1.Use(authMW)
	v1.Use(rateLimiter.Middleware())
	{
		// User endpoints
		v1.GET("/me", handlers.GetMe(fs))
		v1.PUT("/me", handlers.UpdateMe(fs))
		v1.DELETE("/me", handlers.DeleteMe(fs))

		// Context endpoints
		v1.GET("/context", handlers.GetContext(fs))
		v1.PUT("/context", handlers.UpdateContext(fs))
		v1.PUT("/context/preference", handlers.UpdateContextPreference(fs))

		// Coach endpoints (to be implemented in Week 1 Day 5-7)
		v1.GET("/coaches", handlers.ListCoaches(fs))
		v1.POST("/coaches", handlers.CreateCoach(fs))
		v1.GET("/coaches/:id", handlers.GetCoach(fs))
		v1.POST("/coaches/:id/fork", handlers.ForkCoach(fs))
		v1.POST("/coaches/:id/publish", handlers.PublishCoach(fs, cfg))

		// Session endpoints (to be implemented in Week 1 Day 5-7)
		v1.GET("/sessions", handlers.ListSessions(fs))
		v1.POST("/sessions", handlers.CreateSession(fs))
		v1.GET("/sessions/:id", handlers.GetSession(fs))
		v1.POST("/sessions/:id/messages", handlers.SendMessage(fs, gm, cfg))
		v1.GET("/sessions/:id/stream", handlers.StreamChat(fs, gm, cfg))

		// Moment endpoints (to be implemented in Week 2)
		v1.POST("/moments/start", handlers.StartMoment(fs, gm, cfg))

		// System endpoints (to be implemented in Week 2)
		v1.GET("/systems", handlers.ListSystems(fs))
		v1.POST("/systems", handlers.CreateSystem(fs))
		v1.GET("/systems/:id", handlers.GetSystem(fs))
		v1.DELETE("/systems/:id", handlers.DeleteSystem(fs))
	}

	return r, nil
}
