package store

import (
	"context"
	"fmt"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// ListActivity returns a project's activity trail, newest first.
func (s *Store) ListActivity(ctx context.Context, projectID string) ([]model.Activity, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT a.id::text, a.project_id::text, a.actor_id::text, u.name,
		       a.type, a.subject, a.note, a.created_at
		FROM activity a
		JOIN users u ON u.id = a.actor_id
		WHERE a.project_id = $1
		ORDER BY a.created_at DESC
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Activity, 0)
	for rows.Next() {
		var a model.Activity
		if err := rows.Scan(&a.ID, &a.ProjectID, &a.ActorID, &a.ActorName,
			&a.Type, &a.Subject, &a.Note, &a.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, a)
	}
	return items, rows.Err()
}

// ListReleases returns a project's releases, newest first.
func (s *Store) ListReleases(ctx context.Context, projectID string) ([]model.Release, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, project_id::text, version, notes, posted_by::text, created_at
		FROM releases
		WHERE project_id = $1
		ORDER BY created_at DESC
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Release, 0)
	for rows.Next() {
		var r model.Release
		if err := rows.Scan(&r.ID, &r.ProjectID, &r.Version, &r.Notes, &r.PostedBy, &r.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, r)
	}
	return items, rows.Err()
}

// CreateRelease records a release, logs it to the activity trail, and notifies
// every other project member — all in one transaction.
func (s *Store) CreateRelease(ctx context.Context, projectID, posterID, posterName, projectName, version string, notes *string) (model.Release, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Release{}, err
	}
	defer tx.Rollback(ctx)

	var r model.Release
	err = tx.QueryRow(ctx, `
		INSERT INTO releases (project_id, version, notes, posted_by)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text, project_id::text, version, notes, posted_by::text, created_at
	`, projectID, version, notes, posterID).
		Scan(&r.ID, &r.ProjectID, &r.Version, &r.Notes, &r.PostedBy, &r.CreatedAt)
	if err != nil {
		return model.Release{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, note)
		VALUES ($1, $2, 'release_shipped', $3, $4)
	`, projectID, posterID, version, notes); err != nil {
		return model.Release{}, err
	}

	body := fmt.Sprintf("%s shipped %s", posterName, version)
	if notes != nil {
		body = fmt.Sprintf("%s — %s", body, *notes)
	}
	if _, err = tx.Exec(ctx, `
		INSERT INTO notifications (recipient_id, project_id, kind, title, body)
		SELECT user_id, $1, 'release', $2, $3
		FROM project_members
		WHERE project_id = $1 AND user_id <> $4
	`, projectID, "New release in "+projectName, body, posterID); err != nil {
		return model.Release{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.Release{}, err
	}
	return r, nil
}

// ListNotifications returns notifications addressed to a user, newest first.
func (s *Store) ListNotifications(ctx context.Context, userID string) ([]model.Notification, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, project_id::text, kind, title, body, read, created_at
		FROM notifications
		WHERE recipient_id = $1
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Notification, 0)
	for rows.Next() {
		var n model.Notification
		if err := rows.Scan(&n.ID, &n.ProjectID, &n.Kind, &n.Title, &n.Body, &n.Read, &n.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, n)
	}
	return items, rows.Err()
}

// MarkNotificationsRead flags all of a user's notifications as read and returns
// the number updated.
func (s *Store) MarkNotificationsRead(ctx context.Context, userID string) (int64, error) {
	tag, err := s.pool.Exec(ctx,
		`UPDATE notifications SET read = true WHERE recipient_id = $1 AND read = false`,
		userID,
	)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
