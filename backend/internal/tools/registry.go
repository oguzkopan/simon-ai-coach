package tools

import (
	"encoding/json"
	"fmt"
)

// ToolOwner represents who owns/executes the tool
type ToolOwner string

const (
	ToolOwnerIOS ToolOwner = "ios"
	ToolOwnerGo  ToolOwner = "go"
)

// ToolCategory represents the category of the tool
type ToolCategory string

const (
	ToolCategoryClient ToolCategory = "client"
	ToolCategoryServer ToolCategory = "server"
)

// Tool represents a tool that can be executed
type Tool struct {
	ID                     string
	Owner                  ToolOwner
	Category               ToolCategory
	RequiresConfirmation   bool
	PermissionDependencies []string
	InputSchema            map[string]interface{}
	OutputSchema           map[string]interface{}
}

// Registry holds all available tools
type Registry struct {
	tools map[string]Tool
}

// NewRegistry creates a new tool registry
func NewRegistry() *Registry {
	r := &Registry{
		tools: make(map[string]Tool),
	}
	
	// Register all tools
	r.registerClientTools()
	r.registerServerTools()
	
	return r
}

// GetTool retrieves a tool by ID
func (r *Registry) GetTool(id string) (Tool, error) {
	tool, ok := r.tools[id]
	if !ok {
		return Tool{}, fmt.Errorf("tool not found: %s", id)
	}
	return tool, nil
}

// ListTools returns all registered tools
func (r *Registry) ListTools() []Tool {
	tools := make([]Tool, 0, len(r.tools))
	for _, tool := range r.tools {
		tools = append(tools, tool)
	}
	return tools
}

// ListClientTools returns all client tools
func (r *Registry) ListClientTools() []Tool {
	tools := make([]Tool, 0)
	for _, tool := range r.tools {
		if tool.Category == ToolCategoryClient {
			tools = append(tools, tool)
		}
	}
	return tools
}

// ListServerTools returns all server tools
func (r *Registry) ListServerTools() []Tool {
	tools := make([]Tool, 0)
	for _, tool := range r.tools {
		if tool.Category == ToolCategoryServer {
			tools = append(tools, tool)
		}
	}
	return tools
}

// ValidateInput validates input against the tool's input schema
func (r *Registry) ValidateInput(toolID string, input map[string]interface{}) error {
	tool, err := r.GetTool(toolID)
	if err != nil {
		return err
	}
	
	// Basic validation - check required fields
	required, ok := tool.InputSchema["required"].([]interface{})
	if ok {
		for _, field := range required {
			fieldName := field.(string)
			if _, exists := input[fieldName]; !exists {
				return fmt.Errorf("missing required field: %s", fieldName)
			}
		}
	}
	
	return nil
}

// CheckPermissions checks if the tool's permission dependencies are met
func (r *Registry) CheckPermissions(toolID string, grantedPermissions []string) error {
	tool, err := r.GetTool(toolID)
	if err != nil {
		return err
	}
	
	// Check if all required permissions are granted
	permissionMap := make(map[string]bool)
	for _, perm := range grantedPermissions {
		permissionMap[perm] = true
	}
	
	for _, requiredPerm := range tool.PermissionDependencies {
		if !permissionMap[requiredPerm] {
			return fmt.Errorf("missing required permission: %s", requiredPerm)
		}
	}
	
	return nil
}

// registerClientTools registers all iOS client tools
func (r *Registry) registerClientTools() {
	// Local Notification Schedule
	r.tools["local_notification_schedule"] = Tool{
		ID:                   "local_notification_schedule",
		Owner:                ToolOwnerIOS,
		Category:             ToolCategoryClient,
		RequiresConfirmation: true,
		PermissionDependencies: []string{"notifications"},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"title", "body", "trigger", "idempotency_key"},
			"properties": map[string]interface{}{
				"title": map[string]interface{}{"type": "string"},
				"body":  map[string]interface{}{"type": "string"},
				"trigger": map[string]interface{}{
					"type": "object",
					"required": []string{"kind"},
					"properties": map[string]interface{}{
						"kind":        map[string]interface{}{"type": "string", "enum": []string{"at_datetime", "after_delay"}},
						"fire_at_iso": map[string]interface{}{"type": "string"},
						"delay_sec":   map[string]interface{}{"type": "integer"},
					},
				},
				"deep_link": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"url": map[string]interface{}{"type": "string"},
					},
				},
				"idempotency_key": map[string]interface{}{"type": "string"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"scheduled_id": map[string]interface{}{"type": "string"},
				"status":       map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Calendar Event Create
	r.tools["calendar_event_create"] = Tool{
		ID:                   "calendar_event_create",
		Owner:                ToolOwnerIOS,
		Category:             ToolCategoryClient,
		RequiresConfirmation: true,
		PermissionDependencies: []string{"calendar"},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"title", "start_iso", "end_iso", "idempotency_key"},
			"properties": map[string]interface{}{
				"title":     map[string]interface{}{"type": "string"},
				"start_iso": map[string]interface{}{"type": "string"},
				"end_iso":   map[string]interface{}{"type": "string"},
				"location":  map[string]interface{}{"type": "string"},
				"notes":     map[string]interface{}{"type": "string"},
				"alarms": map[string]interface{}{
					"type": "array",
					"items": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"lead_minutes": map[string]interface{}{"type": "integer"},
						},
					},
				},
				"idempotency_key": map[string]interface{}{"type": "string"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"event_id": map[string]interface{}{"type": "string"},
				"status":   map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Reminder Create
	r.tools["reminder_create"] = Tool{
		ID:                   "reminder_create",
		Owner:                ToolOwnerIOS,
		Category:             ToolCategoryClient,
		RequiresConfirmation: true,
		PermissionDependencies: []string{"reminders"},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"title", "idempotency_key"},
			"properties": map[string]interface{}{
				"title":    map[string]interface{}{"type": "string"},
				"notes":    map[string]interface{}{"type": "string"},
				"due_iso":  map[string]interface{}{"type": "string"},
				"priority": map[string]interface{}{"type": "integer"},
				"alarms": map[string]interface{}{
					"type": "array",
					"items": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"lead_minutes": map[string]interface{}{"type": "integer"},
						},
					},
				},
				"idempotency_key": map[string]interface{}{"type": "string"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"reminder_id": map[string]interface{}{"type": "string"},
				"status":      map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Share Sheet Export
	r.tools["share_sheet_export"] = Tool{
		ID:                   "share_sheet_export",
		Owner:                ToolOwnerIOS,
		Category:             ToolCategoryClient,
		RequiresConfirmation: true,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"format", "payload_ref", "idempotency_key"},
			"properties": map[string]interface{}{
				"format": map[string]interface{}{"type": "string", "enum": []string{"markdown", "pdf", "text"}},
				"payload_ref": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"type": map[string]interface{}{"type": "string"},
						"id":   map[string]interface{}{"type": "string"},
					},
				},
				"idempotency_key": map[string]interface{}{"type": "string"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"status": map[string]interface{}{"type": "string"},
			},
		},
	}
}

// registerServerTools registers all Go server tools
func (r *Registry) registerServerTools() {
	// Memory Read
	r.tools["memory_read"] = Tool{
		ID:                     "memory_read",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid", "query"},
			"properties": map[string]interface{}{
				"uid":   map[string]interface{}{"type": "string"},
				"query": map[string]interface{}{"type": "string"},
				"limit": map[string]interface{}{"type": "integer"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"hits": map[string]interface{}{
					"type": "array",
					"items": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"type":    map[string]interface{}{"type": "string"},
							"id":      map[string]interface{}{"type": "string"},
							"snippet": map[string]interface{}{"type": "string"},
							"score":   map[string]interface{}{"type": "number"},
						},
					},
				},
			},
		},
	}
	
	// Memory Write
	r.tools["memory_write"] = Tool{
		ID:                     "memory_write",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid", "patch"},
			"properties": map[string]interface{}{
				"uid": map[string]interface{}{"type": "string"},
				"patch": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"commitments_add": map[string]interface{}{"type": "array"},
						"preferences_set": map[string]interface{}{"type": "object"},
						"redactions":      map[string]interface{}{"type": "array"},
					},
				},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"status": map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Plan Create
	r.tools["plan_create"] = Tool{
		ID:                     "plan_create",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid", "coach_id", "plan"},
			"properties": map[string]interface{}{
				"uid":      map[string]interface{}{"type": "string"},
				"coach_id": map[string]interface{}{"type": "string"},
				"plan": map[string]interface{}{
					"type": "object",
					"required": []string{"title", "objective", "horizon"},
					"properties": map[string]interface{}{
						"title":        map[string]interface{}{"type": "string"},
						"objective":    map[string]interface{}{"type": "string"},
						"horizon":      map[string]interface{}{"type": "string"},
						"milestones":   map[string]interface{}{"type": "array"},
						"next_actions": map[string]interface{}{"type": "array"},
					},
				},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"plan_id": map[string]interface{}{"type": "string"},
				"status":  map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Plan Update
	r.tools["plan_update"] = Tool{
		ID:                     "plan_update",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid", "plan_id", "updates"},
			"properties": map[string]interface{}{
				"uid":     map[string]interface{}{"type": "string"},
				"plan_id": map[string]interface{}{"type": "string"},
				"updates": map[string]interface{}{"type": "object"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"status": map[string]interface{}{"type": "string"},
			},
		},
	}
	
	// Plan List Active
	r.tools["plan_list_active"] = Tool{
		ID:                     "plan_list_active",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid"},
			"properties": map[string]interface{}{
				"uid":   map[string]interface{}{"type": "string"},
				"limit": map[string]interface{}{"type": "integer"},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"plans": map[string]interface{}{
					"type":  "array",
					"items": map[string]interface{}{"type": "object"},
				},
			},
		},
	}
	
	// Check-in Schedule
	r.tools["checkin_schedule"] = Tool{
		ID:                     "checkin_schedule",
		Owner:                  ToolOwnerGo,
		Category:               ToolCategoryServer,
		RequiresConfirmation:   false,
		PermissionDependencies: []string{},
		InputSchema: map[string]interface{}{
			"type": "object",
			"required": []string{"uid", "coach_id", "cadence", "channel"},
			"properties": map[string]interface{}{
				"uid":      map[string]interface{}{"type": "string"},
				"coach_id": map[string]interface{}{"type": "string"},
				"cadence": map[string]interface{}{
					"type": "object",
					"required": []string{"kind", "hour", "minute"},
					"properties": map[string]interface{}{
						"kind":     map[string]interface{}{"type": "string", "enum": []string{"daily", "weekdays", "weekly", "custom_cron"}},
						"hour":     map[string]interface{}{"type": "integer"},
						"minute":   map[string]interface{}{"type": "integer"},
						"weekdays": map[string]interface{}{"type": "array"},
						"cron":     map[string]interface{}{"type": "string"},
					},
				},
				"channel": map[string]interface{}{"type": "string", "enum": []string{"in_app", "local_notification_proposal"}},
			},
		},
		OutputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"checkin_id": map[string]interface{}{"type": "string"},
				"status":     map[string]interface{}{"type": "string"},
			},
		},
	}
}

// MarshalToolSchema marshals a tool's schema to JSON
func MarshalToolSchema(schema map[string]interface{}) (string, error) {
	b, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		return "", err
	}
	return string(b), nil
}
