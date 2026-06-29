package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func scanUser(row pgx.Row) (model.User, error) {
	var u model.User
	err := row.Scan(&u.ID, &u.Email, &u.Name, &u.AvatarHue, &u.EmailNotifications, &u.CreatedAt)
	return u, err
}

// UpsertUser returns the user with the given email, creating them (with the
// supplied name and avatar hue) if they do not already exist.
func (s *Store) UpsertUser(ctx context.Context, email, name string, hue int) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		INSERT INTO users (email, name, avatar_hue)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
		RETURNING id::text, email, name, avatar_hue, email_notifications, created_at
	`, email, name, hue)
	u, err := scanUser(row)
	return u, err
}

func (s *Store) GetUser(ctx context.Context, id string) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id::text, email, name, avatar_hue, email_notifications, created_at
		FROM users WHERE id = $1
	`, id)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	return u, err
}

// SetEmailNotifications toggles Pro email alerts for a user.
func (s *Store) SetEmailNotifications(ctx context.Context, userID string, enabled bool) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		UPDATE users SET email_notifications = $2 WHERE id = $1
		RETURNING id::text, email, name, avatar_hue, email_notifications, created_at
	`, userID, enabled)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	return u, err
}

// ListProEmailRecipients returns creator/developer members of a project who
// opted into email notifications on a Pro plan.
func (s *Store) ListProEmailRecipients(ctx context.Context, projectID string) ([]model.User, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT u.id::text, u.email, u.name, u.avatar_hue, u.email_notifications, u.created_at
		FROM project_members m
		JOIN users u ON u.id = m.user_id
		JOIN subscriptions s ON s.user_id = u.id AND s.plan = 'pro'
		WHERE m.project_id = $1
		  AND m.role IN ('creator', 'developer')
		  AND u.email_notifications = true
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.User, 0)
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}
