package cache

import (
	"context"
	"sync"
	"time"
)

// Cache provides a simple in-memory cache with TTL
type Cache struct {
	mu    sync.RWMutex
	items map[string]*cacheItem
}

type cacheItem struct {
	value      interface{}
	expiration time.Time
}

// New creates a new cache instance
func New() *Cache {
	c := &Cache{
		items: make(map[string]*cacheItem),
	}
	
	// Start cleanup goroutine
	go c.cleanupExpired()
	
	return c
}

// Get retrieves a value from the cache
func (c *Cache) Get(key string) (interface{}, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	
	item, exists := c.items[key]
	if !exists {
		return nil, false
	}
	
	// Check if expired
	if time.Now().After(item.expiration) {
		return nil, false
	}
	
	return item.value, true
}

// Set stores a value in the cache with TTL
func (c *Cache) Set(key string, value interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	
	c.items[key] = &cacheItem{
		value:      value,
		expiration: time.Now().Add(ttl),
	}
}

// Delete removes a value from the cache
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	
	delete(c.items, key)
}

// Clear removes all items from the cache
func (c *Cache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	
	c.items = make(map[string]*cacheItem)
}

// cleanupExpired removes expired items periodically
func (c *Cache) cleanupExpired() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	
	for range ticker.C {
		c.mu.Lock()
		now := time.Now()
		for key, item := range c.items {
			if now.After(item.expiration) {
				delete(c.items, key)
			}
		}
		c.mu.Unlock()
	}
}

// GetOrSet retrieves a value from cache or sets it using the provided function
func (c *Cache) GetOrSet(ctx context.Context, key string, ttl time.Duration, fn func() (interface{}, error)) (interface{}, error) {
	// Try to get from cache first
	if value, exists := c.Get(key); exists {
		return value, nil
	}
	
	// Not in cache, call function to get value
	value, err := fn()
	if err != nil {
		return nil, err
	}
	
	// Store in cache
	c.Set(key, value, ttl)
	
	return value, nil
}
