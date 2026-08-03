package store

import (
	"context"
	"strings"
)

// UpsertDeviceToken associates an FCM token with a user (refreshes platform on conflict).
func (s *Store) UpsertDeviceToken(ctx context.Context, userID, token, platform string) error {
	token = strings.TrimSpace(token)
	platform = strings.TrimSpace(platform)
	if token == "" || platform == "" {
		return nil
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO device_tokens (user_id, token, platform)
		VALUES ($1, $2, $3)
		ON CONFLICT (token) DO UPDATE
		SET user_id = EXCLUDED.user_id,
		    platform = EXCLUDED.platform,
		    updated_at = now()
	`, userID, token, platform)
	return err
}

// DeleteDeviceToken removes a token (e.g. on sign-out).
func (s *Store) DeleteDeviceToken(ctx context.Context, userID, token string) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`,
		userID, strings.TrimSpace(token),
	)
	return err
}

// DeleteDeviceTokenByValue removes a stale token regardless of owner.
func (s *Store) DeleteDeviceTokenByValue(ctx context.Context, token string) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM device_tokens WHERE token = $1`,
		strings.TrimSpace(token),
	)
	return err
}

// ListDeviceTokensForUsers returns FCM tokens for users who have push enabled.
func (s *Store) ListDeviceTokensForUsers(ctx context.Context, userIDs []string) ([]string, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT dt.token
		FROM device_tokens dt
		JOIN users u ON u.id = dt.user_id
		WHERE dt.user_id = ANY($1::uuid[])
		  AND u.push_notifications = true
	`, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tokens := make([]string, 0)
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// ListProjectPushRecipients returns user IDs of all project members except [excludeUserID].
func (s *Store) ListProjectPushRecipients(ctx context.Context, projectID, excludeUserID string) ([]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT m.user_id::text
		FROM project_members m
		JOIN users u ON u.id = m.user_id
		WHERE m.project_id = $1
		  AND m.user_id <> $2
		  AND u.push_notifications = true
	`, projectID, excludeUserID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanStringIDs(rows)
}

// ListDeveloperPushRecipients returns creator/developer user IDs with push enabled.
func (s *Store) ListDeveloperPushRecipients(ctx context.Context, projectID string) ([]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT m.user_id::text
		FROM project_members m
		JOIN users u ON u.id = m.user_id
		WHERE m.project_id = $1
		  AND m.role IN ('creator', 'developer')
		  AND u.push_notifications = true
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanStringIDs(rows)
}

func scanStringIDs(rows interface {
	Next() bool
	Scan(dest ...any) error
	Err() error
}) ([]string, error) {
	out := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}
