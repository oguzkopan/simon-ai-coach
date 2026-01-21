package handlers

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"simon-backend/internal/firestore"
	"simon-backend/internal/logger"
	"simon-backend/internal/models"
	"simon-backend/internal/tools"
)

// ToolsHandler handles tool execution endpoints
type ToolsHandler struct {
	fs       *firestore.Client
	registry *tools.Registry
	log      *logger.Logger
}

// NewToolsHandler creates a new tools handler
func NewToolsHandler(fs *firestore.Client, registry *tools.Registry, log *logger.Logger) *ToolsHandler {
	return &ToolsHandler{
		fs:       fs,
		registry: registry,
		log:      log,
	}
}

// ToolExecuteRequest represents a tool execution request
type ToolExecuteRequest struct {
	ToolID    string                 `json:"tool_id"`
	SessionID string                 `json:"session_id,omitempty"`
	Input     map[string]interface{} `json:"input"`
}

// ToolExecuteResponse represents a tool execution response
type ToolExecuteResponse struct {
	ToolRunID      string                 `json:"tool_run_id"`
	Status         string                 `json:"status"`
	ExecutionToken string                 `json:"execution_token,omitempty"`
	Output         map[string]interface{} `json:"output,omitempty"`
}

// ToolResultRequest represents a tool result submission
type ToolResultRequest struct {
	ToolRunID      string                 `json:"tool_run_id"`
	ExecutionToken string                 `json:"execution_token"`
	Status         string                 `json:"status"` // "executed" | "failed"
	Output         map[string]interface{} `json:"output,omitempty"`
	Error          string                 `json:"error,omitempty"`
}

// ToolResultResponse represents a tool result response
type ToolResultResponse struct {
	Status string `json:"status"`
}

// HandleExecute handles POST /v1/tools/execute
func (h *ToolsHandler) HandleExecute(c *gin.Context) {
	ctx := c.Request.Context()
	uid := c.GetString("uid")

	var req ToolExecuteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.log.Error(ctx, "Failed to decode tool execute request", err, nil)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Get tool from registry
	tool, err := h.registry.GetTool(req.ToolID)
	if err != nil {
		h.log.Error(ctx, "Tool not found", err, map[string]interface{}{"tool_id": req.ToolID})
		c.JSON(http.StatusNotFound, gin.H{"error": "Tool not found"})
		return
	}

	// Validate input against schema
	if err := h.registry.ValidateInput(req.ToolID, req.Input); err != nil {
		h.log.Error(ctx, "Tool input validation failed", err, map[string]interface{}{"tool_id": req.ToolID})
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid input: %v", err)})
		return
	}

	// Check entitlements (basic check - can be enhanced with RevenueCat)
	if err := h.checkEntitlements(ctx, uid, req.ToolID); err != nil {
		h.log.Error(ctx, "Entitlement check failed", err, map[string]interface{}{"uid": uid, "tool_id": req.ToolID})
		c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient entitlements"})
		return
	}

	// Check rate limits (basic check - can be enhanced)
	if err := h.checkRateLimit(ctx, uid, req.ToolID); err != nil {
		h.log.Error(ctx, "Rate limit exceeded", err, map[string]interface{}{"uid": uid, "tool_id": req.ToolID})
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Rate limit exceeded"})
		return
	}

	// Create tool run record
	toolRunID := generateID("toolrun")
	executionToken := generateToken()

	toolRun := models.ToolRun{
		ID:             toolRunID,
		UID:            uid,
		ToolID:         req.ToolID,
		SessionID:      req.SessionID,
		Input:          req.Input,
		Status:         "pending",
		ExecutionToken: executionToken,
		CreatedAt:      models.Now(),
		UpdatedAt:      models.Now(),
	}

	// For server tools, execute immediately
	if tool.Owner == tools.ToolOwnerGo {
		output, err := h.executeServerTool(ctx, tool, req.Input, uid)
		if err != nil {
			toolRun.Status = "failed"
			toolRun.Error = err.Error()
			h.log.Error(ctx, "Server tool execution failed", err, map[string]interface{}{"tool_id": req.ToolID})
		} else {
			toolRun.Status = "executed"
			toolRun.Output = output
		}
	}

	// Save tool run
	if _, err := h.fs.DB.Collection("tool_runs").Doc(toolRunID).Set(ctx, toolRun); err != nil {
		h.log.Error(ctx, "Failed to save tool run", err, nil)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		return
	}

	// Build response
	response := ToolExecuteResponse{
		ToolRunID: toolRunID,
		Status:    toolRun.Status,
	}

	// For client tools, return execution token
	if tool.Owner == tools.ToolOwnerIOS {
		response.ExecutionToken = executionToken
	}

	// For server tools, return output
	if tool.Owner == tools.ToolOwnerGo {
		response.Output = toolRun.Output
	}

	c.JSON(http.StatusOK, response)
}

// HandleResult handles POST /v1/tools/result
func (h *ToolsHandler) HandleResult(c *gin.Context) {
	ctx := c.Request.Context()
	uid := c.GetString("uid")

	var req ToolResultRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.log.Error(ctx, "Failed to decode tool result request", err, nil)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Get tool run
	toolRunDoc, err := h.fs.DB.Collection("tool_runs").Doc(req.ToolRunID).Get(ctx)
	if err != nil {
		h.log.Error(ctx, "Tool run not found", err, map[string]interface{}{"tool_run_id": req.ToolRunID})
		c.JSON(http.StatusNotFound, gin.H{"error": "Tool run not found"})
		return
	}

	var toolRun models.ToolRun
	if err := toolRunDoc.DataTo(&toolRun); err != nil {
		h.log.Error(ctx, "Failed to parse tool run", err, nil)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		return
	}

	// Verify ownership
	if toolRun.UID != uid {
		h.log.Error(ctx, "Unauthorized tool result submission", nil, map[string]interface{}{"uid": uid, "tool_run_uid": toolRun.UID})
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	// Verify execution token
	if toolRun.ExecutionToken != req.ExecutionToken {
		h.log.Error(ctx, "Invalid execution token", nil, map[string]interface{}{"tool_run_id": req.ToolRunID})
		c.JSON(http.StatusForbidden, gin.H{"error": "Invalid execution token"})
		return
	}

	// Update tool run
	updates := map[string]interface{}{
		"status":     req.Status,
		"updated_at": models.Now(),
	}

	if req.Output != nil {
		updates["output"] = req.Output
	}
	if req.Error != "" {
		updates["error"] = req.Error
	}

	if _, err := h.fs.DB.Collection("tool_runs").Doc(req.ToolRunID).Set(ctx, updates); err != nil {
		h.log.Error(ctx, "Failed to update tool run", err, nil)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		return
	}

	response := ToolResultResponse{
		Status: "updated",
	}

	c.JSON(http.StatusOK, response)
}

// executeServerTool executes a server-side tool
func (h *ToolsHandler) executeServerTool(ctx context.Context, tool tools.Tool, input map[string]interface{}, uid string) (map[string]interface{}, error) {
	switch tool.ID {
	case "memory_read":
		memoryService := tools.NewMemoryService(h.fs.DB)
		
		// Parse input
		query, _ := input["query"].(string)
		limit, _ := input["limit"].(float64)
		
		req := tools.MemoryReadRequest{
			UID:   uid,
			Query: query,
			Limit: int(limit),
		}
		
		resp, err := memoryService.Read(ctx, req)
		if err != nil {
			return nil, err
		}
		
		// Convert to map
		output := map[string]interface{}{
			"hits": resp.Hits,
		}
		return output, nil

	case "memory_write":
		memoryService := tools.NewMemoryService(h.fs.DB)
		
		// Parse input
		patchData, _ := input["patch"].(map[string]interface{})
		
		var patch tools.MemoryPatch
		// Convert patch data to MemoryPatch struct
		if patchJSON, err := json.Marshal(patchData); err == nil {
			json.Unmarshal(patchJSON, &patch)
		}
		
		req := tools.MemoryWriteRequest{
			UID:   uid,
			Patch: patch,
		}
		
		if err := memoryService.Write(ctx, req); err != nil {
			return nil, err
		}
		
		return map[string]interface{}{"status": "written"}, nil

	case "plan_create":
		planService := tools.NewPlanService(h.fs.DB)
		
		// Parse input
		coachID, _ := input["coach_id"].(string)
		planData, _ := input["plan"].(map[string]interface{})
		
		var plan models.Plan
		if planJSON, err := json.Marshal(planData); err == nil {
			json.Unmarshal(planJSON, &plan)
		}
		
		req := tools.PlanCreateRequest{
			UID:     uid,
			CoachID: coachID,
			Plan:    plan,
		}
		
		resp, err := planService.Create(ctx, req)
		if err != nil {
			return nil, err
		}
		
		return map[string]interface{}{
			"plan_id": resp.PlanID,
			"status":  resp.Status,
		}, nil

	case "plan_update":
		planService := tools.NewPlanService(h.fs.DB)
		
		// Parse input
		planID, _ := input["plan_id"].(string)
		updates, _ := input["updates"].(map[string]interface{})
		
		req := tools.PlanUpdateRequest{
			UID:     uid,
			PlanID:  planID,
			Updates: updates,
		}
		
		resp, err := planService.Update(ctx, req)
		if err != nil {
			return nil, err
		}
		
		return map[string]interface{}{"status": resp.Status}, nil

	case "plan_list_active":
		planService := tools.NewPlanService(h.fs.DB)
		
		// Parse input
		limit, _ := input["limit"].(float64)
		
		req := tools.PlanListRequest{
			UID:   uid,
			Limit: int(limit),
		}
		
		resp, err := planService.ListActive(ctx, req)
		if err != nil {
			return nil, err
		}
		
		return map[string]interface{}{"plans": resp.Plans}, nil

	case "checkin_schedule":
		checkinService := tools.NewCheckinService(h.fs.DB)
		
		// Parse input
		coachID, _ := input["coach_id"].(string)
		channel, _ := input["channel"].(string)
		cadenceData, _ := input["cadence"].(map[string]interface{})
		
		var cadence models.CheckinCadence
		if cadenceJSON, err := json.Marshal(cadenceData); err == nil {
			json.Unmarshal(cadenceJSON, &cadence)
		}
		
		req := tools.CheckinScheduleRequest{
			UID:     uid,
			CoachID: coachID,
			Cadence: cadence,
			Channel: channel,
		}
		
		resp, err := checkinService.Schedule(ctx, req)
		if err != nil {
			return nil, err
		}
		
		return map[string]interface{}{
			"checkin_id": resp.CheckinID,
			"status":     resp.Status,
		}, nil

	default:
		return nil, fmt.Errorf("unknown server tool: %s", tool.ID)
	}
}

// checkEntitlements checks if user has required entitlements
func (h *ToolsHandler) checkEntitlements(ctx context.Context, uid, toolID string) error {
	// Basic implementation - can be enhanced with RevenueCat integration
	// For now, allow all tools for authenticated users
	return nil
}

// checkRateLimit checks if user has exceeded rate limits
func (h *ToolsHandler) checkRateLimit(ctx context.Context, uid, toolID string) error {
	// Basic implementation - can be enhanced with proper rate limiting
	// For now, allow all requests
	return nil
}

// generateToken generates a secure random token
func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

// generateID generates a unique ID with prefix
func generateID(prefix string) string {
	return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
}
