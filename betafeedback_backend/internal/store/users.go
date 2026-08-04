package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

const userColumns = `id::text, email, name, avatar_hue, email_notifications, push_notifications,
	open_to_test, open_to_swap, tester_bio, created_at`

func scanUser(row pgx.Row) (model.User, error) {
	var u model.User
	err := row.Scan(
		&u.ID, &u.Email, &u.Name, &u.AvatarHue,
		&u.EmailNotifications, &u.PushNotifications,
		&u.OpenToTest, &u.OpenToSwap, &u.TesterBio, &u.CreatedAt,
	)
	return u, err
}

// UpsertUser returns the user with the given email, creating them (with the
// supplied name and avatar hue) if they do not already exist.
func (s *Store) UpsertUser(ctx context.Context, email, name string, hue int) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		INSERT INTO users (email, name, avatar_hue)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
		RETURNING `+userColumns+`
	`, email, name, hue)
	return scanUser(row)
}

func (s *Store) GetUser(ctx context.Context, id string) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE id = $1
	`, id)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	_ = s.attachTesterStats(ctx, &u)
	return u, nil
}

func (s *Store) attachTesterStats(ctx context.Context, u *model.User) error {
	return s.pool.QueryRow(ctx, `
		SELECT COALESCE(AVG(score), 0), COUNT(*)::int
		FROM tester_ratings WHERE tester_id = $1
	`, u.ID).Scan(&u.TesterRatingAvg, &u.TesterRatingCount)
}

// SetEmailNotifications toggles email alerts for a user.
func (s *Store) SetEmailNotifications(ctx context.Context, userID string, enabled bool) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		UPDATE users SET email_notifications = $2 WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, enabled)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	_ = s.attachTesterStats(ctx, &u)
	return u, nil
}

// SetPushNotifications toggles mobile push alerts for a user.
func (s *Store) SetPushNotifications(ctx context.Context, userID string, enabled bool) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		UPDATE users SET push_notifications = $2 WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, enabled)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	_ = s.attachTesterStats(ctx, &u)
	return u, nil
}

// UpdateTesterProfile sets marketplace opt-in, swap opt-in, and bio for the current user.
func (s *Store) UpdateTesterProfile(ctx context.Context, userID string, openToTest, openToSwap bool, bio string) (model.User, error) {
	row := s.pool.QueryRow(ctx, `
		UPDATE users SET open_to_test = $2, open_to_swap = $3, tester_bio = $4 WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, openToTest, openToSwap, bio)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	_ = s.attachTesterStats(ctx, &u)
	return u, nil
}

// ListProEmailRecipients returns creator/developer members of a project who
// opted into email notifications.
func (s *Store) ListProEmailRecipients(ctx context.Context, projectID string) ([]model.User, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT u.id::text, u.email, u.name, u.avatar_hue, u.email_notifications, u.push_notifications,
		       u.open_to_test, u.open_to_swap, u.tester_bio, u.created_at
		FROM project_members m
		JOIN users u ON u.id = m.user_id
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
