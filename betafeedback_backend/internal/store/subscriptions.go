package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

const FreeProjectLimit = 1

// GetSubscription returns the user's subscription (defaulting to free) together
// with how many projects they have created.
func (s *Store) GetSubscription(ctx context.Context, userID string) (model.Subscription, error) {
	sub := model.Subscription{
		Plan:             "free",
		Status:           "active",
		Seats:            1,
		ProjectLimit:     intPtr(FreeProjectLimit),
		ProjectsCreated:  0,
	}

	var (
		renews *time.Time
		limit  *int
		plan   string
		status string
		seats  int
	)
	err := s.pool.QueryRow(ctx, `
		SELECT plan, status, renews_on, seats, project_limit
		FROM subscriptions WHERE user_id = $1
	`, userID).Scan(&plan, &status, &renews, &seats, &limit)
	if err == nil {
		sub.Plan, sub.Status, sub.Seats, sub.ProjectLimit = plan, status, seats, limit
		sub.RenewsOn = formatDate(renews)
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return model.Subscription{}, err
	}

	if err := s.pool.QueryRow(ctx,
		`SELECT count(*) FROM projects WHERE creator_id = $1`, userID,
	).Scan(&sub.ProjectsCreated); err != nil {
		return model.Subscription{}, err
	}
	return sub, nil
}

// UserIsPro reports whether the user currently has Pro access.
// past_due still has access until RevenueCat sends EXPIRATION.
func (s *Store) UserIsPro(ctx context.Context, userID string) (bool, error) {
	sub, err := s.GetSubscription(ctx, userID)
	if err != nil {
		return false, err
	}
	if sub.Plan != "pro" {
		return false, nil
	}
	switch sub.Status {
	case "active", "trialing", "past_due":
		return true, nil
	default:
		return false, nil
	}
}

// CanUserCreateProject checks the user's plan limit against projects they own.
func (s *Store) CanUserCreateProject(ctx context.Context, userID string) (bool, error) {
	sub, err := s.GetSubscription(ctx, userID)
	if err != nil {
		return false, err
	}
	if sub.ProjectLimit == nil {
		return true, nil
	}
	return sub.ProjectsCreated < *sub.ProjectLimit, nil
}

// SetPlan upserts the user's subscription, deriving limits and renewal date
// from the chosen plan. Used by the development stub endpoint only.
func (s *Store) SetPlan(ctx context.Context, userID, plan string) (model.Subscription, error) {
	var renews *time.Time
	if plan == "pro" {
		t := time.Now().AddDate(0, 0, 30)
		renews = &t
	}
	return s.SetSubscriptionFromBilling(ctx, userID, plan, "active", renews, "", "")
}

// SetSubscriptionFromBilling upserts plan state from RevenueCat (or the dev stub).
func (s *Store) SetSubscriptionFromBilling(
	ctx context.Context,
	userID, plan, status string,
	renews *time.Time,
	rcEventID, rcProductID string,
) (model.Subscription, error) {
	var limit *int
	switch plan {
	case "pro":
		limit = nil
	default:
		plan = "free"
		limit = intPtr(FreeProjectLimit)
		if status == "" {
			status = "active"
		}
	}
	if status == "" {
		status = "active"
	}

	var eventID, productID *string
	if rcEventID != "" {
		eventID = &rcEventID
	}
	if rcProductID != "" {
		productID = &rcProductID
	}

	if _, err := s.pool.Exec(ctx, `
		INSERT INTO subscriptions (
			user_id, plan, status, renews_on, seats, project_limit,
			rc_event_id, rc_product_id, updated_at
		)
		VALUES ($1, $2, $3, $4, 1, $5, $6, $7, now())
		ON CONFLICT (user_id) DO UPDATE
		SET plan = EXCLUDED.plan,
		    status = EXCLUDED.status,
		    renews_on = EXCLUDED.renews_on,
		    seats = 1,
		    project_limit = EXCLUDED.project_limit,
		    rc_event_id = COALESCE(EXCLUDED.rc_event_id, subscriptions.rc_event_id),
		    rc_product_id = COALESCE(EXCLUDED.rc_product_id, subscriptions.rc_product_id),
		    updated_at = now()
	`, userID, plan, status, renews, limit, eventID, productID); err != nil {
		return model.Subscription{}, err
	}

	// Email notifications are a Pro perk — clear when downgrading.
	if plan == "free" {
		if _, err := s.pool.Exec(ctx,
			`UPDATE users SET email_notifications = false WHERE id = $1`, userID,
		); err != nil {
			return model.Subscription{}, err
		}
	}

	return s.GetSubscription(ctx, userID)
}

// UserExists reports whether a user id is present (for RevenueCat app_user_id mapping).
func (s *Store) UserExists(ctx context.Context, userID string) (bool, error) {
	var n int
	err := s.pool.QueryRow(ctx, `SELECT 1 FROM users WHERE id = $1`, userID).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func intPtr(v int) *int { return &v }

func formatDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format("2006-01-02")
	return &s
}
