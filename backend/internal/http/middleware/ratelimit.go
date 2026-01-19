package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimiter implements token bucket rate limiting per user
type RateLimiter struct {
	mu      sync.RWMutex
	buckets map[string]*bucket
	rate    int           // requests per window
	window  time.Duration // time window
}

type bucket struct {
	tokens     int
	lastRefill time.Time
}

// NewRateLimiter creates a new rate limiter
// rate: number of requests allowed per window
// window: time window duration
func NewRateLimiter(rate int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		buckets: make(map[string]*bucket),
		rate:    rate,
		window:  window,
	}

	// Cleanup old buckets every 5 minutes
	go rl.cleanup()

	return rl
}

// Middleware returns a Gin middleware function
func (rl *RateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := GetUID(c)
		if uid == "" {
			// No UID, skip rate limiting (shouldn't happen with auth middleware)
			c.Next()
			return
		}

		if !rl.allow(uid) {
			// Calculate retry-after seconds
			retryAfter := rl.getRetryAfter(uid)

			c.Header("Retry-After", retryAfter)
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "rate limit exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// allow checks if a request is allowed for the given UID
func (rl *RateLimiter) allow(uid string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	b, exists := rl.buckets[uid]
	if !exists {
		// Create new bucket
		b = &bucket{
			tokens:     rl.rate - 1, // Consume one token
			lastRefill: time.Now(),
		}
		rl.buckets[uid] = b
		return true
	}

	// Refill tokens based on elapsed time
	now := time.Now()
	elapsed := now.Sub(b.lastRefill)

	if elapsed >= rl.window {
		// Full refill
		b.tokens = rl.rate - 1
		b.lastRefill = now
		return true
	}

	// Partial refill (linear)
	tokensToAdd := int(float64(rl.rate) * (elapsed.Seconds() / rl.window.Seconds()))
	b.tokens = min(b.tokens+tokensToAdd, rl.rate)
	b.lastRefill = now

	if b.tokens > 0 {
		b.tokens--
		return true
	}

	return false
}

// getRetryAfter returns the number of seconds until the next token is available
func (rl *RateLimiter) getRetryAfter(uid string) string {
	rl.mu.RLock()
	defer rl.mu.RUnlock()

	b, exists := rl.buckets[uid]
	if !exists {
		return "0"
	}

	elapsed := time.Since(b.lastRefill)
	remaining := rl.window - elapsed

	if remaining <= 0 {
		return "0"
	}

	return remaining.Round(time.Second).String()
}

// cleanup removes old buckets to prevent memory leaks
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		rl.mu.Lock()
		now := time.Now()
		for uid, b := range rl.buckets {
			if now.Sub(b.lastRefill) > rl.window*2 {
				delete(rl.buckets, uid)
			}
		}
		rl.mu.Unlock()
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
