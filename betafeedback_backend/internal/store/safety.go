package store

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

var validReportReasons = map[string]bool{
	"spam":          true,
	"harassment":    true,
	"inappropriate": true,
	"other":         true,
}

// UsersBlocked reports whether either user has blocked the other.
func (s *Store) UsersBlocked(ctx context.Context, a, b string) (bool, error) {
	var blocked bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM user_blocks
			WHERE (blocker_id = $1 AND blocked_id = $2)
			   OR (blocker_id = $2 AND blocked_id = $1)
		)
	`, a, b).Scan(&blocked)
	return blocked, err
}

// BlockUser records a block and cancels pending invites/swaps between the pair.
func (s *Store) BlockUser(ctx context.Context, blockerID, blockedID string) error {
	if blockerID == blockedID {
		return fmt.Errorf("%w: cannot block yourself", ErrConflict)
	}

	var exists bool
	err := s.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM users WHERE id = $1)`, blockedID).Scan(&exists)
	if err != nil {
		return err
	}
	if !exists {
		return ErrNotFound
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, `
		INSERT INTO user_blocks (blocker_id, blocked_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, blockerID, blockedID); err != nil {
		return err
	}

	if _, err := tx.Exec(ctx, `
		UPDATE tester_invitations
		SET status = 'cancelled', responded_at = now()
		WHERE status = 'pending'
		  AND (
		    (from_user_id = $1 AND to_user_id = $2)
		    OR (from_user_id = $2 AND to_user_id = $1)
		  )
	`, blockerID, blockedID); err != nil {
		return err
	}

	if _, err := tx.Exec(ctx, `
		UPDATE test_swaps
		SET status = 'cancelled', responded_at = now()
		WHERE status = 'pending'
		  AND (
		    (from_user_id = $1 AND to_user_id = $2)
		    OR (from_user_id = $2 AND to_user_id = $1)
		  )
	`, blockerID, blockedID); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// UnblockUser removes a block placed by blockerID.
func (s *Store) UnblockUser(ctx context.Context, blockerID, blockedID string) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2
	`, blockerID, blockedID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CreateUserReport stores a content/user safety report.
func (s *Store) CreateUserReport(ctx context.Context, reporterID, reportedUserID, reason, details string) (model.UserReport, error) {
	reason = strings.ToLower(strings.TrimSpace(reason))
	if !validReportReasons[reason] {
		return model.UserReport{}, fmt.Errorf("%w: invalid reason", ErrConflict)
	}
	if reporterID == reportedUserID {
		return model.UserReport{}, fmt.Errorf("%w: cannot report yourself", ErrConflict)
	}
	details = strings.TrimSpace(details)
	if len(details) > 1000 {
		return model.UserReport{}, fmt.Errorf("%w: details must be 1000 characters or fewer", ErrConflict)
	}

	var exists bool
	err := s.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM users WHERE id = $1)`, reportedUserID).Scan(&exists)
	if err != nil {
		return model.UserReport{}, err
	}
	if !exists {
		return model.UserReport{}, ErrNotFound
	}

	var id string
	err = s.pool.QueryRow(ctx, `
		INSERT INTO user_reports (reporter_id, reported_user_id, reason, details)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text
	`, reporterID, reportedUserID, reason, details).Scan(&id)
	if err != nil {
		return model.UserReport{}, err
	}
	return s.GetUserReport(ctx, id)
}

func (s *Store) GetUserReport(ctx context.Context, id string) (model.UserReport, error) {
	row := s.pool.QueryRow(ctx, userReportSelect+` WHERE r.id = $1`, id)
	rep, err := scanUserReport(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.UserReport{}, ErrNotFound
	}
	return rep, err
}

const userReportSelect = `
		SELECT
			r.id::text,
			r.reporter_id::text, COALESCE(NULLIF(rp.name, ''), rp.email), rp.email,
			r.reported_user_id::text, COALESCE(NULLIF(rd.name, ''), rd.email), rd.email,
			r.reason, r.details, r.created_at
		FROM user_reports r
		JOIN users rp ON rp.id = r.reporter_id
		JOIN users rd ON rd.id = r.reported_user_id`

func scanUserReport(row pgx.Row) (model.UserReport, error) {
	var r model.UserReport
	err := row.Scan(
		&r.ID,
		&r.ReporterID, &r.ReporterName, &r.ReporterEmail,
		&r.ReportedUserID, &r.ReportedName, &r.ReportedEmail,
		&r.Reason, &r.Details, &r.CreatedAt,
	)
	return r, err
}

// AdminListReports returns recent safety reports, newest first.
func (s *Store) AdminListReports(ctx context.Context, limit, offset int) ([]model.UserReport, int, error) {
	limit, offset = clampAdminPage(limit, offset)
	var total int
	if err := s.pool.QueryRow(ctx, `SELECT count(*)::int FROM user_reports`).Scan(&total); err != nil {
		return nil, 0, err
	}
	rows, err := s.pool.Query(ctx, userReportSelect+`
		ORDER BY r.created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]model.UserReport, 0)
	for rows.Next() {
		rep, err := scanUserReport(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, rep)
	}
	return items, total, rows.Err()
}

// DeleteUser permanently removes a user and content they own.
// Returns IDs of projects they created so callers can delete uploaded media.
func (s *Store) DeleteUser(ctx context.Context, userID string) ([]string, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	rows, err := tx.Query(ctx, `SELECT id::text FROM projects WHERE creator_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	projectIDs := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		projectIDs = append(projectIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if _, err := tx.Exec(ctx, `DELETE FROM projects WHERE creator_id = $1`, userID); err != nil {
		return nil, err
	}

	// Remaining rows on other people's projects still reference this user.
	if _, err := tx.Exec(ctx, `DELETE FROM feedback WHERE author_id = $1`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM feedback_comments WHERE author_id = $1`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE structured_bugs SET structured_by = NULL WHERE structured_by = $1
	`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE structured_bugs SET fixed_by = NULL WHERE fixed_by = $1
	`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE test_items SET created_by = NULL WHERE created_by = $1
	`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM releases WHERE posted_by = $1`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM activity WHERE actor_id = $1`, userID); err != nil {
		return nil, err
	}

	tag, err := tx.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrNotFound
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return projectIDs, nil
}
