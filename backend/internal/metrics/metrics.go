package metrics

import (
	"context"
	"sync"
	"time"
)

// Metrics tracks application metrics
type Metrics struct {
	mu sync.RWMutex
	
	// Request metrics
	requestCount    map[string]int64
	requestDuration map[string][]time.Duration
	
	// Pipeline metrics
	pipelineSteps   map[string]time.Duration
	pipelineErrors  int64
	
	// Tool metrics
	toolExecutions  map[string]int64
	toolErrors      map[string]int64
	
	// SSE metrics
	sseConnections  int64
	sseDisconnects  int64
	sseErrors       int64
	
	// Error metrics
	errorsByType    map[string]int64
}

var (
	instance *Metrics
	once     sync.Once
)

// Get returns the singleton metrics instance
func Get() *Metrics {
	once.Do(func() {
		instance = &Metrics{
			requestCount:    make(map[string]int64),
			requestDuration: make(map[string][]time.Duration),
			pipelineSteps:   make(map[string]time.Duration),
			toolExecutions:  make(map[string]int64),
			toolErrors:      make(map[string]int64),
			errorsByType:    make(map[string]int64),
		}
	})
	return instance
}

// RecordRequest records a request metric
func (m *Metrics) RecordRequest(endpoint string, duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.requestCount[endpoint]++
	m.requestDuration[endpoint] = append(m.requestDuration[endpoint], duration)
	
	// Keep only last 1000 durations per endpoint
	if len(m.requestDuration[endpoint]) > 1000 {
		m.requestDuration[endpoint] = m.requestDuration[endpoint][1:]
	}
}

// RecordPipelineStep records a pipeline step duration
func (m *Metrics) RecordPipelineStep(step string, duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.pipelineSteps[step] = duration
}

// RecordPipelineError records a pipeline error
func (m *Metrics) RecordPipelineError() {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.pipelineErrors++
}

// RecordToolExecution records a tool execution
func (m *Metrics) RecordToolExecution(toolID string, success bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.toolExecutions[toolID]++
	if !success {
		m.toolErrors[toolID]++
	}
}

// RecordSSEConnection records an SSE connection
func (m *Metrics) RecordSSEConnection() {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.sseConnections++
}

// RecordSSEDisconnect records an SSE disconnection
func (m *Metrics) RecordSSEDisconnect() {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.sseDisconnects++
}

// RecordSSEError records an SSE error
func (m *Metrics) RecordSSEError() {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.sseErrors++
}

// RecordError records an error by type
func (m *Metrics) RecordError(errorType string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.errorsByType[errorType]++
}

// GetStats returns current metrics statistics
func (m *Metrics) GetStats() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	stats := make(map[string]interface{})
	
	// Request stats
	requestStats := make(map[string]interface{})
	for endpoint, count := range m.requestCount {
		durations := m.requestDuration[endpoint]
		avg := calculateAverage(durations)
		p95 := calculatePercentile(durations, 0.95)
		
		requestStats[endpoint] = map[string]interface{}{
			"count":   count,
			"avg_ms":  avg.Milliseconds(),
			"p95_ms":  p95.Milliseconds(),
		}
	}
	stats["requests"] = requestStats
	
	// Pipeline stats
	pipelineStats := make(map[string]interface{})
	for step, duration := range m.pipelineSteps {
		pipelineStats[step] = duration.Milliseconds()
	}
	pipelineStats["errors"] = m.pipelineErrors
	stats["pipeline"] = pipelineStats
	
	// Tool stats
	toolStats := make(map[string]interface{})
	for toolID, count := range m.toolExecutions {
		errors := m.toolErrors[toolID]
		successRate := float64(count-errors) / float64(count) * 100
		
		toolStats[toolID] = map[string]interface{}{
			"executions":   count,
			"errors":       errors,
			"success_rate": successRate,
		}
	}
	stats["tools"] = toolStats
	
	// SSE stats
	stats["sse"] = map[string]interface{}{
		"connections": m.sseConnections,
		"disconnects": m.sseDisconnects,
		"errors":      m.sseErrors,
		"active":      m.sseConnections - m.sseDisconnects,
	}
	
	// Error stats
	stats["errors"] = m.errorsByType
	
	return stats
}

// calculateAverage calculates the average duration
func calculateAverage(durations []time.Duration) time.Duration {
	if len(durations) == 0 {
		return 0
	}
	
	var total time.Duration
	for _, d := range durations {
		total += d
	}
	
	return total / time.Duration(len(durations))
}

// calculatePercentile calculates the percentile duration
func calculatePercentile(durations []time.Duration, percentile float64) time.Duration {
	if len(durations) == 0 {
		return 0
	}
	
	// Simple percentile calculation (not sorting for performance)
	// In production, use a proper percentile library
	index := int(float64(len(durations)) * percentile)
	if index >= len(durations) {
		index = len(durations) - 1
	}
	
	return durations[index]
}

// Timer helps measure duration
type Timer struct {
	start time.Time
}

// NewTimer creates a new timer
func NewTimer() *Timer {
	return &Timer{start: time.Now()}
}

// Stop stops the timer and returns the duration
func (t *Timer) Stop() time.Duration {
	return time.Since(t.start)
}

// StopAndRecord stops the timer and records the metric
func (t *Timer) StopAndRecord(m *Metrics, key string) {
	duration := time.Since(t.start)
	m.RecordPipelineStep(key, duration)
}

// WithContext adds metrics to context
func WithContext(ctx context.Context) context.Context {
	return context.WithValue(ctx, metricsKey, Get())
}

// FromContext retrieves metrics from context
func FromContext(ctx context.Context) *Metrics {
	if m, ok := ctx.Value(metricsKey).(*Metrics); ok {
		return m
	}
	return Get()
}

type contextKey string

const metricsKey contextKey = "metrics"
