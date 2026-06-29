package store

import (
	"context"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func (s *Store) ListTestItems(ctx context.Context, projectID string) ([]model.TestItem, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, project_id::text, title, details, created_at
		FROM test_items
		WHERE project_id = $1
		ORDER BY position, created_at
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.TestItem, 0)
	for rows.Next() {
		var t model.TestItem
		if err := rows.Scan(&t.ID, &t.ProjectID, &t.Title, &t.Details, &t.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, t)
	}
	return items, rows.Err()
}

func (s *Store) AddTestItem(ctx context.Context, projectID, title string, details *string, createdBy string) (model.TestItem, error) {
	var t model.TestItem
	err := s.pool.QueryRow(ctx, `
		INSERT INTO test_items (project_id, title, details, created_by, position)
		VALUES ($1, $2, $3, $4, COALESCE((SELECT max(position) + 1 FROM test_items WHERE project_id = $1), 0))
		RETURNING id::text, project_id::text, title, details, created_at
	`, projectID, title, details, createdBy).
		Scan(&t.ID, &t.ProjectID, &t.Title, &t.Details, &t.CreatedAt)
	return t, err
}

// RemoveTestItem deletes an item, returning ErrNotFound when nothing matched.
func (s *Store) RemoveTestItem(ctx context.Context, projectID, itemID string) error {
	tag, err := s.pool.Exec(ctx,
		`DELETE FROM test_items WHERE id = $1 AND project_id = $2`, itemID, projectID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
