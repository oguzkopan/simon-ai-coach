package logger

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Severity levels for structured logging
type Severity string

const (
	SeverityDebug    Severity = "DEBUG"
	SeverityInfo     Severity = "INFO"
	SeverityWarning  Severity = "WARNING"
	SeverityError    Severity = "ERROR"
	SeverityCritical Severity = "CRITICAL"
)

// LogEntry represents a structured log entry
type LogEntry struct {
	Severity  Severity               `json:"severity"`
	Message   string                 `json:"message"`
	Timestamp time.Time              `json:"timestamp"`
	RequestID string                 `json:"request_id,omitempty"`
	UID       string                 `json:"uid,omitempty"`
	Fields    map[string]interface{} `json:"fields,omitempty"`
	Error     string                 `json:"error,omitempty"`
}

// Logger provides structured logging
type Logger struct {
	logger *log.Logger
}

// New creates a new logger
func New() *Logger {
	return &Logger{
		logger: log.New(os.Stdout, "", 0),
	}
}

// Debug logs a debug message
func (l *Logger) Debug(ctx context.Context, message string, fields map[string]interface{}) {
	l.log(ctx, SeverityDebug, message, fields, nil)
}

// Info logs an info message
func (l *Logger) Info(ctx context.Context, message string, fields map[string]interface{}) {
	l.log(ctx, SeverityInfo, message, fields, nil)
}

// Warning logs a warning message
func (l *Logger) Warning(ctx context.Context, message string, fields map[string]interface{}) {
	l.log(ctx, SeverityWarning, message, fields, nil)
}

// Error logs an error message
func (l *Logger) Error(ctx context.Context, message string, err error, fields map[string]interface{}) {
	l.log(ctx, SeverityError, message, fields, err)
}

// Critical logs a critical error message
func (l *Logger) Critical(ctx context.Context, message string, err error, fields map[string]interface{}) {
	l.log(ctx, SeverityCritical, message, fields, err)
}

// log writes a structured log entry
func (l *Logger) log(ctx context.Context, severity Severity, message string, fields map[string]interface{}, err error) {
	entry := LogEntry{
		Severity:  severity,
		Message:   message,
		Timestamp: time.Now().UTC(),
		Fields:    fields,
	}

	// Extract request ID from context
	if requestID := getRequestID(ctx); requestID != "" {
		entry.RequestID = requestID
	}

	// Extract UID from context
	if uid := getUID(ctx); uid != "" {
		entry.UID = uid
	}

	// Add error if present
	if err != nil {
		entry.Error = err.Error()
	}

	// Marshal to JSON
	data, marshalErr := json.Marshal(entry)
	if marshalErr != nil {
		l.logger.Printf(`{"severity":"ERROR","message":"failed to marshal log entry","error":"%s"}`, marshalErr.Error())
		return
	}

	l.logger.Println(string(data))
}

// Context keys
type contextKey string

const (
	requestIDKey contextKey = "request_id"
	uidKey       contextKey = "uid"
)

// getRequestID extracts request ID from context
func getRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey).(string); ok {
		return id
	}
	return ""
}

// getUID extracts UID from context
func getUID(ctx context.Context) string {
	if uid, ok := ctx.Value(uidKey).(string); ok {
		return uid
	}
	return ""
}

// WithRequestID adds request ID to context
func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}

// WithUID adds UID to context
func WithUID(ctx context.Context, uid string) context.Context {
	return context.WithValue(ctx, uidKey, uid)
}

// RequestIDMiddleware adds a unique request ID to each request
func RequestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := uuid.New().String()
		c.Set("request_id", requestID)
		c.Header("X-Request-ID", requestID)

		// Add to context
		ctx := WithRequestID(c.Request.Context(), requestID)
		c.Request = c.Request.WithContext(ctx)

		c.Next()
	}
}

// LoggingMiddleware logs HTTP requests
func LoggingMiddleware(logger *Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		duration := time.Since(start)
		statusCode := c.Writer.Status()

		fields := map[string]interface{}{
			"method":      method,
			"path":        path,
			"status_code": statusCode,
			"duration_ms": duration.Milliseconds(),
			"client_ip":   c.ClientIP(),
		}

		// Add UID if available
		if uid, exists := c.Get("uid"); exists {
			fields["uid"] = uid
		}

		// Log based on status code
		if statusCode >= 500 {
			logger.Error(c.Request.Context(), "HTTP request failed", nil, fields)
		} else if statusCode >= 400 {
			logger.Warning(c.Request.Context(), "HTTP request client error", fields)
		} else {
			logger.Info(c.Request.Context(), "HTTP request completed", fields)
		}
	}
}

// Global logger instance
var defaultLogger = New()

// Convenience functions using default logger
func Debug(ctx context.Context, message string, fields map[string]interface{}) {
	defaultLogger.Debug(ctx, message, fields)
}

func Info(ctx context.Context, message string, fields map[string]interface{}) {
	defaultLogger.Info(ctx, message, fields)
}

func Warning(ctx context.Context, message string, fields map[string]interface{}) {
	defaultLogger.Warning(ctx, message, fields)
}

func Error(ctx context.Context, message string, err error, fields map[string]interface{}) {
	defaultLogger.Error(ctx, message, err, fields)
}

func Critical(ctx context.Context, message string, err error, fields map[string]interface{}) {
	defaultLogger.Critical(ctx, message, err, fields)
}
