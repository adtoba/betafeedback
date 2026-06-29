package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// GetFeedback returns a single feedback item scoped to a project.
func (s *Store) GetFeedback(ctx context.Context, projectID, feedbackID string) (model.Feedback, error) {
	var f model.Feedback
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, project_id::text, author_id::text, title, body, device, app_version, platform, created_at
		FROM feedback WHERE id = $1 AND project_id = $2
	`, feedbackID, projectID).
		Scan(&f.ID, &f.ProjectID, &f.AuthorID, &f.Title, &f.Body, &f.Device, &f.AppVersion, &f.Platform, &f.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Feedback{}, ErrNotFound
	}
	return f, err
}

// CreateFeedback inserts a tester report and its screenshot placeholders.
func (s *Store) CreateFeedback(ctx context.Context, f model.Feedback) (model.Feedback, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Feedback{}, err
	}
	defer tx.Rollback(ctx)

	err = tx.QueryRow(ctx, `
		INSERT INTO feedback (project_id, author_id, title, body, device, app_version, platform)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id::text, created_at, (SELECT name FROM users WHERE id = author_id)
	`, f.ProjectID, f.AuthorID, f.Title, f.Body, f.Device, f.AppVersion, f.Platform).
		Scan(&f.ID, &f.CreatedAt, &f.AuthorName)
	if err != nil {
		return model.Feedback{}, err
	}

	for i, shot := range f.Screenshots {
		if _, err = tx.Exec(ctx, `
			INSERT INTO feedback_screenshots (feedback_id, label, hue, position, url, content_type)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, f.ID, shot.Label, shot.Hue, i, shot.URL, shot.ContentType); err != nil {
			return model.Feedback{}, err
		}
	}

	if err = tx.Commit(ctx); err != nil {
		return model.Feedback{}, err
	}
	if f.Screenshots == nil {
		f.Screenshots = []model.Screenshot{}
	}
	return f, nil
}

// ListFeedback returns a project's tester reports (with author and screenshots),
// newest first.
func (s *Store) ListFeedback(ctx context.Context, projectID string) ([]model.Feedback, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.id::text, f.project_id::text, f.author_id::text, u.name,
		       f.title, f.body, f.device, f.app_version, f.platform, f.created_at
		FROM feedback f
		JOIN users u ON u.id = f.author_id
		WHERE f.project_id = $1
		ORDER BY f.created_at DESC
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Feedback, 0)
	index := make(map[string]int)
	for rows.Next() {
		var f model.Feedback
		f.Screenshots = []model.Screenshot{}
		if err := rows.Scan(&f.ID, &f.ProjectID, &f.AuthorID, &f.AuthorName,
			&f.Title, &f.Body, &f.Device, &f.AppVersion, &f.Platform, &f.CreatedAt); err != nil {
			return nil, err
		}
		index[f.ID] = len(items)
		items = append(items, f)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return items, nil
	}

	shots, err := s.pool.Query(ctx, `
		SELECT feedback_id::text, label, hue, COALESCE(url, ''), COALESCE(content_type, '')
		FROM feedback_screenshots
		WHERE feedback_id IN (
			SELECT id FROM feedback WHERE project_id = $1
		)
		ORDER BY position
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer shots.Close()
	for shots.Next() {
		var feedbackID string
		var shot model.Screenshot
		if err := shots.Scan(&feedbackID, &shot.Label, &shot.Hue, &shot.URL, &shot.ContentType); err != nil {
			return nil, err
		}
		if i, ok := index[feedbackID]; ok {
			items[i].Screenshots = append(items[i].Screenshots, shot)
		}
	}
	if err := shots.Err(); err != nil {
		return nil, err
	}
	if err := s.attachFeedbackComments(ctx, projectID, items); err != nil {
		return nil, err
	}
	return items, nil
}
