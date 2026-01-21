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
	Blueprint  map[string]interface{} `firestore:"blueprint" json:"blueprint"` // Deprecated: use CoachSpec instead
	CoachSpec  *CoachSpec             `firestore:"coachSpec,omitempty" json:"coachSpec,omitempty"`
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
	UID               string             `firestore:"uid" json:"uid"`
	DisplayName       string             `firestore:"display_name,omitempty" json:"display_name,omitempty"`
	PhotoURL          string             `firestore:"photo_url,omitempty" json:"photo_url,omitempty"`
	Email             string             `firestore:"email,omitempty" json:"email,omitempty"`
	Credits           int                `firestore:"credits" json:"credits"`
	ContextVault      UserContext        `firestore:"context_vault" json:"context_vault"`
	Preferences       Preferences        `firestore:"preferences" json:"preferences"`
	MemorySummary     string             `firestore:"memory_summary,omitempty" json:"memory_summary,omitempty"`
	Commitments       []Commitment       `firestore:"commitments,omitempty" json:"commitments,omitempty"`
	SubscriptionCache *SubscriptionCache `firestore:"subscription_cache,omitempty" json:"subscription_cache,omitempty"`
	CreatedAt         time.Time          `firestore:"created_at" json:"created_at"`
	UpdatedAt         time.Time          `firestore:"updated_at" json:"updated_at"`
}

// SubscriptionCache represents cached subscription data from RevenueCat
type SubscriptionCache struct {
	Entitlements      map[string]bool `firestore:"entitlements" json:"entitlements"`
	ProductIdentifier string          `firestore:"product_identifier,omitempty" json:"product_identifier,omitempty"`
	ExpiresDate       *time.Time      `firestore:"expires_date,omitempty" json:"expires_date,omitempty"`
	PeriodType        string          `firestore:"period_type,omitempty" json:"period_type,omitempty"` // "trial" | "intro" | "normal"
	Store             string          `firestore:"store,omitempty" json:"store,omitempty"`             // "app_store" | "play_store"
	LastUpdated       time.Time       `firestore:"last_updated" json:"last_updated"`
}

// Preferences represents user preferences
type Preferences struct {
	IncludeContext bool `firestore:"include_context" json:"include_context"`
}

// Commitment represents a user commitment
type Commitment struct {
	ID        string    `firestore:"id" json:"id"`
	Text      string    `firestore:"text" json:"text"`
	CreatedAt time.Time `firestore:"created_at" json:"created_at"`
	Status    string    `firestore:"status" json:"status"` // "active" | "completed" | "abandoned"
}

// Plan represents a structured plan
type Plan struct {
	ID          string       `firestore:"id" json:"id"`
	UID         string       `firestore:"uid" json:"uid"`
	CoachID     string       `firestore:"coach_id" json:"coach_id"`
	Title       string       `firestore:"title" json:"title"`
	Objective   string       `firestore:"objective" json:"objective"`
	Horizon     string       `firestore:"horizon" json:"horizon"` // "today" | "week" | "month" | "quarter"
	Milestones  []Milestone  `firestore:"milestones,omitempty" json:"milestones,omitempty"`
	NextActions []NextAction `firestore:"next_actions,omitempty" json:"next_actions,omitempty"`
	Status      string       `firestore:"status" json:"status"` // "active" | "completed" | "archived"
	CreatedAt   time.Time    `firestore:"created_at" json:"created_at"`
	UpdatedAt   time.Time    `firestore:"updated_at" json:"updated_at"`
}

// Milestone represents a plan milestone
type Milestone struct {
	ID          string    `firestore:"id" json:"id"`
	Title       string    `firestore:"title" json:"title"`
	Description string    `firestore:"description,omitempty" json:"description,omitempty"`
	DueDate     time.Time `firestore:"due_date,omitempty" json:"due_date,omitempty"`
	Status      string    `firestore:"status" json:"status"` // "pending" | "in_progress" | "completed"
}

// NextAction represents an actionable task
type NextAction struct {
	ID          string    `firestore:"id" json:"id"`
	Title       string    `firestore:"title" json:"title"`
	DurationMin int       `firestore:"duration_min,omitempty" json:"duration_min,omitempty"`
	Energy      string    `firestore:"energy,omitempty" json:"energy,omitempty"` // "low" | "medium" | "high"
	When        *When     `firestore:"when,omitempty" json:"when,omitempty"`
	Status      string    `firestore:"status" json:"status"` // "pending" | "completed"
	CompletedAt time.Time `firestore:"completed_at,omitempty" json:"completed_at,omitempty"`
}

// When represents timing for an action
type When struct {
	Kind     string    `firestore:"kind" json:"kind"` // "now" | "today_window" | "schedule_exact"
	StartISO time.Time `firestore:"start_iso,omitempty" json:"start_iso,omitempty"`
	EndISO   time.Time `firestore:"end_iso,omitempty" json:"end_iso,omitempty"`
}

// Checkin represents a scheduled check-in
type Checkin struct {
	ID        string          `firestore:"id" json:"id"`
	UID       string          `firestore:"uid" json:"uid"`
	CoachID   string          `firestore:"coach_id" json:"coach_id"`
	Cadence   CheckinCadence  `firestore:"cadence" json:"cadence"`
	Channel   string          `firestore:"channel" json:"channel"` // "in_app" | "local_notification_proposal"
	NextRunAt time.Time       `firestore:"next_run_at" json:"next_run_at"`
	LastRunAt *time.Time      `firestore:"last_run_at,omitempty" json:"last_run_at,omitempty"`
	Status    string          `firestore:"status" json:"status"` // "active" | "paused" | "deleted"
	CreatedAt time.Time       `firestore:"created_at" json:"created_at"`
	UpdatedAt time.Time       `firestore:"updated_at" json:"updated_at"`
}

// CheckinCadence represents the schedule for check-ins
type CheckinCadence struct {
	Kind     string `firestore:"kind" json:"kind"` // "daily" | "weekdays" | "weekly" | "custom_cron"
	Hour     int    `firestore:"hour" json:"hour"`
	Minute   int    `firestore:"minute" json:"minute"`
	Weekdays []int  `firestore:"weekdays,omitempty" json:"weekdays,omitempty"` // 1=Sun, 7=Sat
	Cron     string `firestore:"cron,omitempty" json:"cron,omitempty"`
}

// ToolRun represents a tool execution record
type ToolRun struct {
	ID              string                 `firestore:"id" json:"id"`
	UID             string                 `firestore:"uid" json:"uid"`
	ToolID          string                 `firestore:"tool_id" json:"tool_id"`
	SessionID       string                 `firestore:"session_id,omitempty" json:"session_id,omitempty"`
	Input           map[string]interface{} `firestore:"input" json:"input"`
	Output          map[string]interface{} `firestore:"output,omitempty" json:"output,omitempty"`
	Status          string                 `firestore:"status" json:"status"` // "pending" | "approved" | "declined" | "executed" | "failed"
	ExecutionToken  string                 `firestore:"execution_token,omitempty" json:"execution_token,omitempty"`
	Error           string                 `firestore:"error,omitempty" json:"error,omitempty"`
	CreatedAt       time.Time              `firestore:"created_at" json:"created_at"`
	UpdatedAt       time.Time              `firestore:"updated_at" json:"updated_at"`
}

// WeeklyReview represents a weekly review structured output
type WeeklyReview struct {
	Wins           []string       `firestore:"wins" json:"wins"`
	Misses         []string       `firestore:"misses" json:"misses"`
	RootCauses     []string       `firestore:"root_causes" json:"root_causes"`
	NextWeekFocus  []string       `firestore:"next_week_focus" json:"next_week_focus"`
	Commitments    []Commitment   `firestore:"commitments" json:"commitments"`
}

// RevenueCatEvent represents a webhook event from RevenueCat
type RevenueCatEvent struct {
	ID               string                 `firestore:"id" json:"id"`
	EventType        string                 `firestore:"event_type" json:"event_type"`
	AppUserID        string                 `firestore:"app_user_id" json:"app_user_id"`
	OriginalAppUserID string                `firestore:"original_app_user_id,omitempty" json:"original_app_user_id,omitempty"`
	ProductID        string                 `firestore:"product_id,omitempty" json:"product_id,omitempty"`
	EntitlementIDs   []string               `firestore:"entitlement_ids,omitempty" json:"entitlement_ids,omitempty"`
	PeriodType       string                 `firestore:"period_type,omitempty" json:"period_type,omitempty"`
	PurchasedAt      *time.Time             `firestore:"purchased_at,omitempty" json:"purchased_at,omitempty"`
	ExpirationAt     *time.Time             `firestore:"expiration_at,omitempty" json:"expiration_at,omitempty"`
	Store            string                 `firestore:"store,omitempty" json:"store,omitempty"`
	Environment      string                 `firestore:"environment" json:"environment"` // "SANDBOX" | "PRODUCTION"
	RawPayload       map[string]interface{} `firestore:"raw_payload" json:"raw_payload"`
	ProcessedAt      time.Time              `firestore:"processed_at" json:"processed_at"`
	CreatedAt        time.Time              `firestore:"created_at" json:"created_at"`
}

// CalendarEvent represents a calendar event stored in Firestore
type CalendarEvent struct {
	ID        string       `firestore:"id" json:"id"`
	UID       string       `firestore:"uid" json:"uid"`
	CoachID   string       `firestore:"coach_id" json:"coach_id"`
	SessionID *string      `firestore:"session_id,omitempty" json:"session_id,omitempty"`
	ToolRunID string       `firestore:"tool_run_id" json:"tool_run_id"`
	
	// Event details
	Title    string       `firestore:"title" json:"title"`
	StartISO string       `firestore:"start_iso" json:"start_iso"`
	EndISO   string       `firestore:"end_iso" json:"end_iso"`
	Location *string      `firestore:"location,omitempty" json:"location,omitempty"`
	Notes    *string      `firestore:"notes,omitempty" json:"notes,omitempty"`
	Alarms   []EventAlarm `firestore:"alarms,omitempty" json:"alarms,omitempty"`
	
	// Native app sync
	EventIdentifier *string `firestore:"event_identifier,omitempty" json:"event_identifier,omitempty"`
	NativeStatus    string  `firestore:"native_status" json:"native_status"` // "created" | "denied_permission" | "failed"
	
	// Metadata
	Status    string    `firestore:"status" json:"status"` // "upcoming" | "past"
	CreatedAt time.Time `firestore:"created_at" json:"created_at"`
	UpdatedAt time.Time `firestore:"updated_at" json:"updated_at"`
}

// EventAlarm represents an alarm/reminder for an event
type EventAlarm struct {
	Kind         string `firestore:"kind" json:"kind"` // "at_datetime" | "minutes_before"
	FireAtISO    string `firestore:"fire_at_iso,omitempty" json:"fire_at_iso,omitempty"`
	MinutesBefore int    `firestore:"minutes_before,omitempty" json:"minutes_before,omitempty"`
}

// Reminder represents a reminder stored in Firestore (different from iOS EventKit reminder)
type Reminder struct {
	ID        string  `firestore:"id" json:"id"`
	UID       string  `firestore:"uid" json:"uid"`
	CoachID   string  `firestore:"coach_id" json:"coach_id"`
	SessionID *string `firestore:"session_id,omitempty" json:"session_id,omitempty"`
	ToolRunID string  `firestore:"tool_run_id" json:"tool_run_id"`
	
	// Reminder details
	Title    string       `firestore:"title" json:"title"`
	Notes    *string      `firestore:"notes,omitempty" json:"notes,omitempty"`
	DueISO   *string      `firestore:"due_iso,omitempty" json:"due_iso,omitempty"`
	Priority int          `firestore:"priority" json:"priority"` // 0-9
	Alarms   []EventAlarm `firestore:"alarms,omitempty" json:"alarms,omitempty"`
	
	// Native app sync
	ReminderIdentifier *string `firestore:"reminder_identifier,omitempty" json:"reminder_identifier,omitempty"`
	NativeStatus       string  `firestore:"native_status" json:"native_status"` // "created" | "denied_permission" | "failed"
	
	// Metadata
	Status      string     `firestore:"status" json:"status"` // "pending" | "completed" | "cancelled"
	CompletedAt *time.Time `firestore:"completed_at,omitempty" json:"completed_at,omitempty"`
	CreatedAt   time.Time  `firestore:"created_at" json:"created_at"`
	UpdatedAt   time.Time  `firestore:"updated_at" json:"updated_at"`
}

// ScheduledNotification represents a scheduled notification stored in Firestore
type ScheduledNotification struct {
	ID        string  `firestore:"id" json:"id"`
	UID       string  `firestore:"uid" json:"uid"`
	CoachID   string  `firestore:"coach_id" json:"coach_id"`
	SessionID *string `firestore:"session_id,omitempty" json:"session_id,omitempty"`
	ToolRunID string  `firestore:"tool_run_id" json:"tool_run_id"`
	
	// Notification details
	Title    string               `firestore:"title" json:"title"`
	Body     string               `firestore:"body" json:"body"`
	Trigger  NotificationTrigger  `firestore:"trigger" json:"trigger"`
	DeepLink *DeepLink            `firestore:"deep_link,omitempty" json:"deep_link,omitempty"`
	
	// Native app sync
	NotificationIdentifier string `firestore:"notification_identifier" json:"notification_identifier"`
	NativeStatus           string `firestore:"native_status" json:"native_status"` // "scheduled" | "denied" | "failed"
	
	// Metadata
	Status      string     `firestore:"status" json:"status"` // "scheduled" | "delivered" | "cancelled"
	DeliveredAt *time.Time `firestore:"delivered_at,omitempty" json:"delivered_at,omitempty"`
	CreatedAt   time.Time  `firestore:"created_at" json:"created_at"`
	UpdatedAt   time.Time  `firestore:"updated_at" json:"updated_at"`
}

// NotificationTrigger represents when a notification should fire
type NotificationTrigger struct {
	Kind      string  `firestore:"kind" json:"kind"` // "at_datetime" | "after_delay"
	FireAtISO *string `firestore:"fire_at_iso,omitempty" json:"fire_at_iso,omitempty"`
	DelaySec  *int    `firestore:"delay_sec,omitempty" json:"delay_sec,omitempty"`
}

// DeepLink represents a deep link for a notification
type DeepLink struct {
	URL string `firestore:"url" json:"url"`
}
