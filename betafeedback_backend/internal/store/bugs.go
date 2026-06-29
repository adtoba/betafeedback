package store

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// ListBugs returns a project's structured bugs (with reporter name), newest
// first. Pass a non-empty status filter to limit results (e.g. "open").
func (s *Store) ListBugs(ctx context.Context, projectID string, statusFilter ...string) ([]model.StructuredBug, error) {
	filter := ""
	args := []any{projectID}
	if len(statusFilter) > 0 && statusFilter[0] != "" {
		filter = " AND b.status = $2"
		args = append(args, statusFilter[0])
	}

	rows, err := s.pool.Query(ctx, `
		SELECT b.id::text, b.project_id::text, b.feedback_id::text, b.title, b.steps,
		       b.expected, b.actual, b.severity, b.status, u.name, b.structured_at, b.fixed_at,
		       b.fix_note, b.fixed_in_release_id::text, r.version
		FROM structured_bugs b
		LEFT JOIN feedback f ON f.id = b.feedback_id
		LEFT JOIN users u ON u.id = f.author_id
		LEFT JOIN releases r ON r.id = b.fixed_in_release_id
		WHERE b.project_id = $1`+filter+`
		ORDER BY b.structured_at DESC
	`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	bugs := make([]model.StructuredBug, 0)
	for rows.Next() {
		bug, err := scanBug(rows)
		if err != nil {
			return nil, err
		}
		bugs = append(bugs, bug)
	}
	return bugs, rows.Err()
}

// UpdateBug edits an open or needs-info bug's fields. Suggested and fixed bugs
// cannot be edited.
func (s *Store) UpdateBug(ctx context.Context, projectID, bugID string, title, expected, actual, severity string, steps []string) (model.StructuredBug, error) {
	stepsJSON, err := json.Marshal(steps)
	if err != nil {
		return model.StructuredBug{}, err
	}

	tag, err := s.pool.Exec(ctx, `
		UPDATE structured_bugs
		SET title = $3, steps = $4::jsonb, expected = $5, actual = $6, severity = $7
		WHERE id = $1 AND project_id = $2 AND status IN ('open', 'needs_info')
	`, bugID, projectID, title, string(stepsJSON), expected, actual, severity)
	if err != nil {
		return model.StructuredBug{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.StructuredBug{}, ErrNotFound
	}
	return s.getBug(ctx, bugID)
}

// MarkBugNeedsInfo moves an open bug to needs_info.
func (s *Store) MarkBugNeedsInfo(ctx context.Context, projectID, bugID, actorID string, note *string) (model.StructuredBug, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.StructuredBug{}, err
	}
	defer tx.Rollback(ctx)

	var title string
	err = tx.QueryRow(ctx, `
		UPDATE structured_bugs
		SET status = 'needs_info'
		WHERE id = $1 AND project_id = $2 AND status = 'open'
		RETURNING title
	`, bugID, projectID).Scan(&title)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.StructuredBug{}, ErrNotFound
	}
	if err != nil {
		return model.StructuredBug{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, note, bug_id)
		VALUES ($1, $2, 'bug_needs_info', $3, $4, $5)
	`, projectID, actorID, title, note, bugID); err != nil {
		return model.StructuredBug{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.StructuredBug{}, err
	}
	return s.getBug(ctx, bugID)
}

// ResumeBug moves a needs_info bug back to open.
func (s *Store) ResumeBug(ctx context.Context, projectID, bugID string) (model.StructuredBug, error) {
	tag, err := s.pool.Exec(ctx, `
		UPDATE structured_bugs
		SET status = 'open'
		WHERE id = $1 AND project_id = $2 AND status = 'needs_info'
	`, bugID, projectID)
	if err != nil {
		return model.StructuredBug{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.StructuredBug{}, ErrNotFound
	}
	return s.getBug(ctx, bugID)
}

// ReopenBug moves a fixed bug back to open and clears fix metadata.
func (s *Store) ReopenBug(ctx context.Context, projectID, bugID, actorID string) (model.StructuredBug, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.StructuredBug{}, err
	}
	defer tx.Rollback(ctx)

	var title string
	err = tx.QueryRow(ctx, `
		UPDATE structured_bugs
		SET status = 'open', fixed_at = NULL, fixed_by = NULL,
		    fix_note = NULL, fixed_in_release_id = NULL
		WHERE id = $1 AND project_id = $2 AND status = 'fixed'
		RETURNING title
	`, bugID, projectID).Scan(&title)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.StructuredBug{}, ErrNotFound
	}
	if err != nil {
		return model.StructuredBug{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, bug_id)
		VALUES ($1, $2, 'bug_reopened', $3, $4)
	`, projectID, actorID, title, bugID); err != nil {
		return model.StructuredBug{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.StructuredBug{}, err
	}
	return s.getBug(ctx, bugID)
}

// MarkBugFixed flips a bug to fixed and logs the activity. Returns ErrNotFound
// if the bug does not belong to the project or is not open.
func (s *Store) MarkBugFixed(ctx context.Context, projectID, bugID, actorID string, fixNote *string, releaseID *string) (model.StructuredBug, error) {
	if releaseID != nil && strings.TrimSpace(*releaseID) != "" {
		var ok bool
		if err := s.pool.QueryRow(ctx,
			`SELECT EXISTS (SELECT 1 FROM releases WHERE id = $1 AND project_id = $2)`,
			*releaseID, projectID,
		).Scan(&ok); err != nil {
			return model.StructuredBug{}, err
		}
		if !ok {
			return model.StructuredBug{}, ErrNotFound
		}
	} else {
		releaseID = nil
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.StructuredBug{}, err
	}
	defer tx.Rollback(ctx)

	var title string
	err = tx.QueryRow(ctx, `
		UPDATE structured_bugs
		SET status = 'fixed', fixed_at = now(), fixed_by = $3,
		    fix_note = $4, fixed_in_release_id = $5
		WHERE id = $1 AND project_id = $2 AND status = 'open'
		RETURNING title
	`, bugID, projectID, actorID, fixNote, releaseID).Scan(&title)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.StructuredBug{}, ErrNotFound
	}
	if err != nil {
		return model.StructuredBug{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, note, bug_id)
		VALUES ($1, $2, 'bug_fixed', $3, $4, $5)
	`, projectID, actorID, title, fixNote, bugID); err != nil {
		return model.StructuredBug{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.StructuredBug{}, err
	}

	return s.getBug(ctx, bugID)
}

func (s *Store) getBug(ctx context.Context, bugID string) (model.StructuredBug, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT b.id::text, b.project_id::text, b.feedback_id::text, b.title, b.steps,
		       b.expected, b.actual, b.severity, b.status, u.name, b.structured_at, b.fixed_at,
		       b.fix_note, b.fixed_in_release_id::text, r.version
		FROM structured_bugs b
		LEFT JOIN feedback f ON f.id = b.feedback_id
		LEFT JOIN users u ON u.id = f.author_id
		LEFT JOIN releases r ON r.id = b.fixed_in_release_id
		WHERE b.id = $1
	`, bugID)
	return scanBug(row)
}

// rowScanner is satisfied by both pgx.Row and pgx.Rows.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanBug(row rowScanner) (model.StructuredBug, error) {
	var bug model.StructuredBug
	var steps []byte
	if err := row.Scan(&bug.ID, &bug.ProjectID, &bug.FeedbackID, &bug.Title, &steps,
		&bug.Expected, &bug.Actual, &bug.Severity, &bug.Status, &bug.ReporterName,
		&bug.StructuredAt, &bug.FixedAt, &bug.FixNote, &bug.FixedInReleaseID, &bug.FixedInReleaseVersion); err != nil {
		return model.StructuredBug{}, err
	}
	if len(steps) > 0 {
		if err := json.Unmarshal(steps, &bug.Steps); err != nil {
			return model.StructuredBug{}, err
		}
	}
	if bug.Steps == nil {
		bug.Steps = []string{}
	}
	return bug, nil
}

// BugForFeedback reports whether a feedback item has already been structured.
func (s *Store) BugForFeedback(ctx context.Context, feedbackID string) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM structured_bugs WHERE feedback_id = $1)`, feedbackID,
	).Scan(&exists)
	return exists, err
}

// StructureFeedback persists a structured bug derived from a feedback item and
// logs the activity, in one transaction.
func (s *Store) StructureFeedback(ctx context.Context, projectID, feedbackID, actorID string, bug model.StructuredBug) (model.StructuredBug, error) {
	steps, err := json.Marshal(bug.Steps)
	if err != nil {
		return model.StructuredBug{}, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.StructuredBug{}, err
	}
	defer tx.Rollback(ctx)

	var id string
	var structuredAt = bug.StructuredAt
	err = tx.QueryRow(ctx, `
		INSERT INTO structured_bugs (project_id, feedback_id, title, steps, expected, actual, severity, structured_by)
		VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, $8)
		RETURNING id::text, structured_at
	`, projectID, feedbackID, bug.Title, string(steps), bug.Expected, bug.Actual, bug.Severity, actorID).
		Scan(&id, &structuredAt)
	if err != nil {
		return model.StructuredBug{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, bug_id)
		VALUES ($1, $2, 'bug_structured', $3, $4)
	`, projectID, actorID, bug.Title, id); err != nil {
		return model.StructuredBug{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.StructuredBug{}, err
	}

	bug.ID = id
	bug.ProjectID = projectID
	bug.FeedbackID = &feedbackID
	bug.Status = "open"
	bug.StructuredAt = structuredAt
	return bug, nil
}

// SuggestBug persists an auto-generated bug draft in the 'suggested' state.
func (s *Store) SuggestBug(ctx context.Context, projectID, feedbackID string, bug model.StructuredBug) (model.StructuredBug, error) {
	steps, err := json.Marshal(bug.Steps)
	if err != nil {
		return model.StructuredBug{}, err
	}

	var id string
	var structuredAt time.Time
	err = s.pool.QueryRow(ctx, `
		INSERT INTO structured_bugs (project_id, feedback_id, title, steps, expected, actual, severity, status)
		VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, 'suggested')
		RETURNING id::text, structured_at
	`, projectID, feedbackID, bug.Title, string(steps), bug.Expected, bug.Actual, bug.Severity).
		Scan(&id, &structuredAt)
	if err != nil {
		return model.StructuredBug{}, err
	}

	bug.ID = id
	bug.ProjectID = projectID
	bug.FeedbackID = &feedbackID
	bug.Status = "suggested"
	bug.StructuredAt = structuredAt
	return bug, nil
}

// ConfirmBug promotes a suggested bug to 'open'.
func (s *Store) ConfirmBug(ctx context.Context, projectID, bugID, actorID string) (model.StructuredBug, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.StructuredBug{}, err
	}
	defer tx.Rollback(ctx)

	var title string
	err = tx.QueryRow(ctx, `
		UPDATE structured_bugs
		SET status = 'open', structured_by = $3, structured_at = now()
		WHERE id = $1 AND project_id = $2 AND status = 'suggested'
		RETURNING title
	`, bugID, projectID, actorID).Scan(&title)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.StructuredBug{}, ErrNotFound
	}
	if err != nil {
		return model.StructuredBug{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO activity (project_id, actor_id, type, subject, bug_id)
		VALUES ($1, $2, 'bug_structured', $3, $4)
	`, projectID, actorID, title, bugID); err != nil {
		return model.StructuredBug{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.StructuredBug{}, err
	}
	return s.getBug(ctx, bugID)
}

// DismissBug deletes a suggested bug draft.
func (s *Store) DismissBug(ctx context.Context, projectID, bugID string) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM structured_bugs
		WHERE id = $1 AND project_id = $2 AND status = 'suggested'
	`, bugID, projectID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
