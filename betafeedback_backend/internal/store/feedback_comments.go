package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// CreateFeedbackComment adds a reply on a feedback thread.
func (s *Store) CreateFeedbackComment(ctx context.Context, projectID, feedbackID, authorID, body string) (model.FeedbackComment, error) {
	var c model.FeedbackComment
	err := s.pool.QueryRow(ctx, `
		INSERT INTO feedback_comments (feedback_id, author_id, body)
		SELECT f.id, $3, $4
		FROM feedback f
		WHERE f.id = $1 AND f.project_id = $2
		RETURNING id::text, feedback_id::text, author_id::text,
		          (SELECT name FROM users WHERE id = author_id), body, created_at
	`, feedbackID, projectID, authorID, body).
		Scan(&c.ID, &c.FeedbackID, &c.AuthorID, &c.AuthorName, &c.Body, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.FeedbackComment{}, ErrNotFound
	}
	return c, err
}

// attachFeedbackComments loads comments for all feedback items in the slice.
func (s *Store) attachFeedbackComments(ctx context.Context, projectID string, items []model.Feedback) error {
	if len(items) == 0 {
		return nil
	}

	index := make(map[string]int, len(items))
	for i, f := range items {
		index[f.ID] = i
		items[i].Comments = []model.FeedbackComment{}
	}

	rows, err := s.pool.Query(ctx, `
		SELECT c.id::text, c.feedback_id::text, c.author_id::text, u.name, c.body, c.created_at
		FROM feedback_comments c
		JOIN users u ON u.id = c.author_id
		WHERE c.feedback_id IN (SELECT id FROM feedback WHERE project_id = $1)
		ORDER BY c.created_at ASC
	`, projectID)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var c model.FeedbackComment
		if err := rows.Scan(&c.ID, &c.FeedbackID, &c.AuthorID, &c.AuthorName, &c.Body, &c.CreatedAt); err != nil {
			return err
		}
		if i, ok := index[c.FeedbackID]; ok {
			items[i].Comments = append(items[i].Comments, c)
		}
	}
	return rows.Err()
}
