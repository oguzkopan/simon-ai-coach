package services

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"simon-backend/internal/cache"
	fsClient "simon-backend/internal/firestore"
	"simon-backend/internal/models"
)

// CoachService handles coach operations with caching
type CoachService struct {
	fs    *fsClient.Client
	cache *cache.Cache
}

// NewCoachService creates a new coach service
func NewCoachService(fs *fsClient.Client) *CoachService {
	return &CoachService{
		fs:    fs,
		cache: cache.New(),
	}
}

// GetCoach retrieves a coach by ID with caching
func (s *CoachService) GetCoach(ctx context.Context, coachID string) (*models.Coach, error) {
	cacheKey := fmt.Sprintf("coach:%s", coachID)
	
	// Try cache first
	value, err := s.cache.GetOrSet(ctx, cacheKey, 15*time.Minute, func() (interface{}, error) {
		doc, err := s.fs.DB.Collection("coaches").Doc(coachID).Get(ctx)
		if err != nil {
			return nil, err
		}
		
		var coach models.Coach
		if err := doc.DataTo(&coach); err != nil {
			return nil, err
		}
		
		return &coach, nil
	})
	
	if err != nil {
		return nil, err
	}
	
	return value.(*models.Coach), nil
}

// InvalidateCoach removes a coach from cache
func (s *CoachService) InvalidateCoach(coachID string) {
	cacheKey := fmt.Sprintf("coach:%s", coachID)
	s.cache.Delete(cacheKey)
}

// PlanService handles plan operations with caching
type PlanService struct {
	fs    *fsClient.Client
	cache *cache.Cache
}

// NewPlanService creates a new plan service
func NewPlanService(fs *fsClient.Client) *PlanService {
	return &PlanService{
		fs:    fs,
		cache: cache.New(),
	}
}

// GetActivePlans retrieves active plans for a user with caching
func (s *PlanService) GetActivePlans(ctx context.Context, uid string) ([]models.Plan, error) {
	cacheKey := fmt.Sprintf("plans:active:%s", uid)
	
	// Try cache first (shorter TTL for user-specific data)
	value, err := s.cache.GetOrSet(ctx, cacheKey, 5*time.Minute, func() (interface{}, error) {
		query := s.fs.DB.Collection("plans").
			Where("uid", "==", uid).
			Where("status", "==", "active").
			OrderBy("created_at", firestore.Desc).
			Limit(10)
		
		docs, err := query.Documents(ctx).GetAll()
		if err != nil {
			return nil, err
		}
		
		plans := make([]models.Plan, 0, len(docs))
		for _, doc := range docs {
			var plan models.Plan
			if err := doc.DataTo(&plan); err != nil {
				continue
			}
			plans = append(plans, plan)
		}
		
		return plans, nil
	})
	
	if err != nil {
		return nil, err
	}
	
	return value.([]models.Plan), nil
}

// InvalidateUserPlans removes user's plans from cache
func (s *PlanService) InvalidateUserPlans(uid string) {
	cacheKey := fmt.Sprintf("plans:active:%s", uid)
	s.cache.Delete(cacheKey)
}
