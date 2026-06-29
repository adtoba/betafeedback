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

// UserIsPro reports whether the user is on an active paid plan.
func (s *Store) UserIsPro(ctx context.Context, userID string) (bool, error) {
	sub, err := s.GetSubscription(ctx, userID)
	if err != nil {
		return false, err
	}
	return sub.Plan == "pro", nil
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
// from the chosen plan.
func (s *Store) SetPlan(ctx context.Context, userID, plan string) (model.Subscription, error) {
	var (
		renews *time.Time
		limit  *int
	)
	switch plan {
	case "free":
		limit = intPtr(FreeProjectLimit)
	case "pro":
		limit = nil
		if t := time.Now().AddDate(0, 0, 30); true {
			renews = &t
		}
	}

	if _, err := s.pool.Exec(ctx, `
		INSERT INTO subscriptions (user_id, plan, status, renews_on, seats, project_limit, updated_at)
		VALUES ($1, $2, 'active', $3, 1, $4, now())
		ON CONFLICT (user_id) DO UPDATE
		SET plan = EXCLUDED.plan, status = EXCLUDED.status, renews_on = EXCLUDED.renews_on,
		    seats = 1, project_limit = EXCLUDED.project_limit, updated_at = now()
	`, userID, plan, renews, limit); err != nil {
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

func intPtr(v int) *int { return &v }

func formatDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format("2006-01-02")
	return &s
}
