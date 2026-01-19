package models

import "time"

// Coach represents an AI coach configuration
type Coach struct {
	ID         string                 `firestore:"id" json:"id"`
	OwnerUID   string                 `firestore:"owner_uid" json:"owner_uid"`
	Visibility string                 `firestore:"visibility" json:"visibility"` // "public" | "private"
	Title      string                 `firestore:"title" json:"title"`
	Promise    string                 `firestore:"promise" json:"promise"`
	Tags       []string               `firestore:"tags" json:"tags"`
	Blueprint  map[string]interface{} `firestore:"blueprint" json:"blueprint"`
	Stats      CoachStats             `firestore:"stats" json:"stats"`
	CreatedAt  time.Time              `firestore:"created_at" json:"created_at"`
	UpdatedAt  time.Time              `firestore:"updated_at" json:"updated_at"`
}

// CoachStats tracks coach usage metrics
type CoachStats struct {
	Starts  int `firestore:"starts" json:"starts"`
	Saves   int `firestore:"saves" json:"saves"`
	Upvotes int `firestore:"upvotes" json:"upvotes"`
}

// Session represents a coaching conversation
type Session struct {
	ID        string    `firestore:"id" json:"id"`
	UID       string    `firestore:"uid" json:"uid"`
	CoachID   *string   `firestore:"coach_id,omitempty" json:"coach_id,omitempty"`
	Title     string    `firestore:"title" json:"title"`
	Mode      string    `firestore:"mode" json:"mode"` // "quick" | "system" | "deep"
	CreatedAt time.Time `firestore:"created_at" json:"created_at"`
	UpdatedAt time.Time `firestore:"updated_at" json:"updated_at"`
}

// Message represents a single message in a conversation
type Message struct {
	ID          string       `firestore:"id" json:"id"`
	Role        string       `firestore:"role" json:"role"` // "user" | "assistant"
	ContentText string       `firestore:"content_text" json:"content_text"`
	Attachments []Attachment `firestore:"attachments,omitempty" json:"attachments,omitempty"`
	CreatedAt   time.Time    `firestore:"created_at" json:"created_at"`
}

// Attachment represents a file attachment
type Attachment struct {
	Type        string `firestore:"type" json:"type"` // "image"
	StoragePath string `firestore:"storage_path" json:"storage_path"`
	DownloadURL string `firestore:"download_url" json:"download_url"`
}

// System represents a pinned system/routine
type System struct {
	ID                 string    `firestore:"id" json:"id"`
	UID                string    `firestore:"uid" json:"uid"`
	Title              string    `firestore:"title" json:"title"`
	Checklist          []string  `firestore:"checklist" json:"checklist"`
	ScheduleSuggestion string    `firestore:"schedule_suggestion,omitempty" json:"schedule_suggestion,omitempty"`
	Metrics            []string  `firestore:"metrics,omitempty" json:"metrics,omitempty"`
	SourceSessionID    string    `firestore:"source_session_id" json:"source_session_id"`
	CreatedAt          time.Time `firestore:"created_at" json:"created_at"`
}

// ChatDelta represents a streaming chat token
type ChatDelta struct {
	Kind  string `json:"kind"`  // "token" | "final" | "error"
	Token string `json:"token,omitempty"`
	Error string `json:"error,omitempty"`
}

// UserContext represents user's personal context
type UserContext struct {
	Values          []string `firestore:"values,omitempty" json:"values,omitempty"`
	Goals           []string `firestore:"goals,omitempty" json:"goals,omitempty"`
	Constraints     []string `firestore:"constraints,omitempty" json:"constraints,omitempty"`
	CurrentProjects []string `firestore:"current_projects,omitempty" json:"current_projects,omitempty"`
}

// CreateSessionRequest represents the request to create a new session
type CreateSessionRequest struct {
	CoachID string `json:"coach_id"`
}

// SendMessageRequest represents the request to send a message
type SendMessageRequest struct {
	UserText    string       `json:"user_text"`
	Attachments []Attachment `json:"attachments,omitempty"`
}

// Now returns the current time (helper for consistency)
func Now() time.Time {
	return time.Now().UTC()
}

// User represents a user profile
type User struct {
	UID          string       `firestore:"uid" json:"uid"`
	DisplayName  string       `firestore:"display_name,omitempty" json:"display_name,omitempty"`
	PhotoURL     string       `firestore:"photo_url,omitempty" json:"photo_url,omitempty"`
	Email        string       `firestore:"email,omitempty" json:"email,omitempty"`
	ContextVault UserContext  `firestore:"context_vault" json:"context_vault"`
	Preferences  Preferences  `firestore:"preferences" json:"preferences"`
	CreatedAt    time.Time    `firestore:"created_at" json:"created_at"`
	UpdatedAt    time.Time    `firestore:"updated_at" json:"updated_at"`
}

// Preferences represents user preferences
type Preferences struct {
	IncludeContext bool `firestore:"include_context" json:"include_context"`
}
