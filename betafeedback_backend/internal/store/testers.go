package store

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// ListOpenTesters returns users who opted into the tester marketplace.
// When projectID is set, flags already-member and pending-invite state and
// excludes the project's creator from results.
func (s *Store) ListOpenTesters(ctx context.Context, viewerID, projectID, query string, limit int) ([]model.TesterProfile, error) {
	if limit <= 0 || limit > 100 {
		limit = 40
	}
	q := strings.TrimSpace(query)

	rows, err := s.pool.Query(ctx, `
		SELECT
			u.id::text,
			u.name,
			u.email,
			u.avatar_hue,
			u.tester_bio,
			COALESCE(AVG(r.score), 0) AS rating_avg,
			COUNT(r.id)::int AS rating_count,
			COALESCE((
				SELECT COUNT(*)::int FROM tester_invitations ti
				WHERE ti.to_user_id = u.id AND ti.status = 'accepted'
			), 0) AS completed_count,
			CASE WHEN $2::uuid IS NOT NULL THEN EXISTS (
				SELECT 1 FROM project_members pm
				WHERE pm.project_id = $2 AND pm.user_id = u.id
			) ELSE false END AS already_member,
			CASE WHEN $2::uuid IS NOT NULL THEN EXISTS (
				SELECT 1 FROM tester_invitations ti
				WHERE ti.project_id = $2 AND ti.to_user_id = u.id AND ti.status = 'pending'
			) ELSE false END AS invite_pending
		FROM users u
		LEFT JOIN tester_ratings r ON r.tester_id = u.id
		WHERE u.open_to_test = true
		  AND u.id <> $1
		  AND ($3 = '' OR u.name ILIKE '%' || $3 || '%'
		       OR u.email ILIKE '%' || $3 || '%'
		       OR u.tester_bio ILIKE '%' || $3 || '%')
		  AND ($2::uuid IS NULL OR u.id <> (SELECT creator_id FROM projects WHERE id = $2))
		GROUP BY u.id
		ORDER BY rating_avg DESC NULLS LAST, rating_count DESC, completed_count DESC, u.name ASC
		LIMIT $4
	`, viewerID, nullUUID(projectID), q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TesterProfile, 0)
	for rows.Next() {
		var t model.TesterProfile
		if err := rows.Scan(
			&t.ID, &t.Name, &t.Email, &t.AvatarHue, &t.TesterBio,
			&t.RatingAvg, &t.RatingCount, &t.CompletedCount,
			&t.AlreadyMember, &t.InvitePending,
		); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListTopTesters returns the highest-rated opted-in testers.
func (s *Store) ListTopTesters(ctx context.Context, viewerID string, limit int) ([]model.TesterProfile, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	rows, err := s.pool.Query(ctx, `
		SELECT
			u.id::text,
			u.name,
			u.email,
			u.avatar_hue,
			u.tester_bio,
			COALESCE(AVG(r.score), 0) AS rating_avg,
			COUNT(r.id)::int AS rating_count,
			COALESCE((
				SELECT COUNT(*)::int FROM tester_invitations ti
				WHERE ti.to_user_id = u.id AND ti.status = 'accepted'
			), 0) AS completed_count,
			false, false
		FROM users u
		LEFT JOIN tester_ratings r ON r.tester_id = u.id
		WHERE u.open_to_test = true
		  AND u.id <> $1
		GROUP BY u.id
		HAVING COUNT(r.id) > 0
		ORDER BY rating_avg DESC, rating_count DESC, completed_count DESC
		LIMIT $2
	`, viewerID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TesterProfile, 0)
	for rows.Next() {
		var t model.TesterProfile
		if err := rows.Scan(
			&t.ID, &t.Name, &t.Email, &t.AvatarHue, &t.TesterBio,
			&t.RatingAvg, &t.RatingCount, &t.CompletedCount,
			&t.AlreadyMember, &t.InvitePending,
		); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func nullUUID(id string) any {
	if strings.TrimSpace(id) == "" {
		return nil
	}
	return id
}

// CreateTesterInvitation invites an opted-in tester to a project.
func (s *Store) CreateTesterInvitation(ctx context.Context, projectID, fromUserID, toUserID, message string) (model.TesterInvitation, error) {
	var open bool
	err := s.pool.QueryRow(ctx, `SELECT open_to_test FROM users WHERE id = $1`, toUserID).Scan(&open)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TesterInvitation{}, ErrNotFound
	}
	if err != nil {
		return model.TesterInvitation{}, err
	}
	if !open {
		return model.TesterInvitation{}, fmt.Errorf("%w: user is not open to testing", ErrConflict)
	}

	var already bool
	if err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM project_members WHERE project_id = $1 AND user_id = $2
		)
	`, projectID, toUserID).Scan(&already); err != nil {
		return model.TesterInvitation{}, err
	}
	if already {
		return model.TesterInvitation{}, fmt.Errorf("%w: user is already a member", ErrConflict)
	}

	row := s.pool.QueryRow(ctx, `
		INSERT INTO tester_invitations (project_id, from_user_id, to_user_id, message)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text
	`, projectID, fromUserID, toUserID, message)
	var id string
	if err := row.Scan(&id); err != nil {
		if isUniqueViolation(err) {
			return model.TesterInvitation{}, fmt.Errorf("%w: invitation already pending", ErrConflict)
		}
		return model.TesterInvitation{}, err
	}

	projectName, _ := s.ProjectName(ctx, projectID)
	title := "Tester invitation"
	body := fmt.Sprintf("You've been invited to test %s", projectName)
	_, _ = s.pool.Exec(ctx, `
		INSERT INTO notifications (recipient_id, project_id, kind, title, body)
		VALUES ($1, $2, 'tester_invite', $3, $4)
	`, toUserID, projectID, title, body)

	return s.GetTesterInvitation(ctx, id)
}

const testerInvitationSelect = `
		SELECT
			i.id::text, i.project_id::text, p.name, p.description, p.logo_url,
			(SELECT count(*)::int FROM project_members pm
			 WHERE pm.project_id = p.id AND pm.role = 'tester') AS tester_count,
			i.from_user_id::text, f.name,
			i.to_user_id::text, tu.name,
			i.message, i.status, i.created_at, i.responded_at
		FROM tester_invitations i
		JOIN projects p ON p.id = i.project_id
		JOIN users f ON f.id = i.from_user_id
		JOIN users tu ON tu.id = i.to_user_id`

// GetTesterInvitation loads a single invitation with project/user names.
func (s *Store) GetTesterInvitation(ctx context.Context, id string) (model.TesterInvitation, error) {
	row := s.pool.QueryRow(ctx, testerInvitationSelect+`
		WHERE i.id = $1
	`, id)
	inv, err := scanTesterInvitation(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TesterInvitation{}, ErrNotFound
	}
	return inv, err
}

func scanTesterInvitation(row pgx.Row) (model.TesterInvitation, error) {
	var inv model.TesterInvitation
	err := row.Scan(
		&inv.ID, &inv.ProjectID, &inv.ProjectName, &inv.ProjectDescription, &inv.ProjectLogoURL,
		&inv.TesterCount,
		&inv.FromUserID, &inv.FromUserName,
		&inv.ToUserID, &inv.ToUserName,
		&inv.Message, &inv.Status, &inv.CreatedAt, &inv.RespondedAt,
	)
	return inv, err
}

// ListIncomingTesterInvitations returns invitations addressed to a user.
func (s *Store) ListIncomingTesterInvitations(ctx context.Context, userID string) ([]model.TesterInvitation, error) {
	rows, err := s.pool.Query(ctx, testerInvitationSelect+`
		WHERE i.to_user_id = $1
		ORDER BY
			CASE WHEN i.status = 'pending' THEN 0 ELSE 1 END,
			i.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TesterInvitation, 0)
	for rows.Next() {
		inv, err := scanTesterInvitation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

// ListProjectTesterInvitations returns invitations sent for a project.
func (s *Store) ListProjectTesterInvitations(ctx context.Context, projectID string) ([]model.TesterInvitation, error) {
	rows, err := s.pool.Query(ctx, testerInvitationSelect+`
		WHERE i.project_id = $1
		ORDER BY i.created_at DESC
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TesterInvitation, 0)
	for rows.Next() {
		inv, err := scanTesterInvitation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

// RespondTesterInvitation accepts or declines a pending invitation.
// On accept, the invitee is added as a tester member.
func (s *Store) RespondTesterInvitation(ctx context.Context, inviteID, userID, status string) (model.TesterInvitation, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.TesterInvitation{}, err
	}
	defer tx.Rollback(ctx)

	var projectID, toUserID, current string
	err = tx.QueryRow(ctx, `
		SELECT project_id::text, to_user_id::text, status
		FROM tester_invitations WHERE id = $1
		FOR UPDATE
	`, inviteID).Scan(&projectID, &toUserID, &current)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TesterInvitation{}, ErrNotFound
	}
	if err != nil {
		return model.TesterInvitation{}, err
	}
	if toUserID != userID {
		return model.TesterInvitation{}, ErrForbidden
	}
	if current != "pending" {
		return model.TesterInvitation{}, fmt.Errorf("%w: invitation is no longer pending", ErrConflict)
	}

	tag, err := tx.Exec(ctx, `
		UPDATE tester_invitations
		SET status = $2, responded_at = now()
		WHERE id = $1 AND status = 'pending'
	`, inviteID, status)
	if err != nil {
		return model.TesterInvitation{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.TesterInvitation{}, fmt.Errorf("%w: invitation is no longer pending", ErrConflict)
	}

	if status == "accepted" {
		if _, err = tx.Exec(ctx, `
			INSERT INTO project_members (project_id, user_id, role)
			VALUES ($1, $2, 'tester')
			ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role
		`, projectID, userID); err != nil {
			return model.TesterInvitation{}, err
		}
	}

	if err = tx.Commit(ctx); err != nil {
		return model.TesterInvitation{}, err
	}
	return s.GetTesterInvitation(ctx, inviteID)
}

// RateTester records or updates a creator's rating for a project tester.
func (s *Store) RateTester(ctx context.Context, projectID, raterID, testerID string, score int, comment string) (model.TesterRating, error) {
	var isTester bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM project_members
			WHERE project_id = $1 AND user_id = $2 AND role = 'tester'
		)
	`, projectID, testerID).Scan(&isTester)
	if err != nil {
		return model.TesterRating{}, err
	}
	if !isTester {
		return model.TesterRating{}, fmt.Errorf("%w: user is not a tester on this project", ErrConflict)
	}
	if raterID == testerID {
		return model.TesterRating{}, fmt.Errorf("%w: cannot rate yourself", ErrConflict)
	}

	row := s.pool.QueryRow(ctx, `
		INSERT INTO tester_ratings (project_id, rater_id, tester_id, score, comment)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (project_id, rater_id, tester_id)
		DO UPDATE SET score = EXCLUDED.score, comment = EXCLUDED.comment, created_at = now()
		RETURNING id::text, project_id::text, rater_id::text, tester_id::text, score, comment, created_at
	`, projectID, raterID, testerID, score, comment)

	var r model.TesterRating
	if err := row.Scan(&r.ID, &r.ProjectID, &r.RaterID, &r.TesterID, &r.Score, &r.Comment, &r.CreatedAt); err != nil {
		return model.TesterRating{}, err
	}
	return r, nil
}

// ListTesterRatingsForUser returns ratings a user has received as a tester,
// newest first, with project and rater names for display.
func (s *Store) ListTesterRatingsForUser(ctx context.Context, testerID string) ([]model.TesterRating, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT r.id::text, r.project_id::text, p.name, r.rater_id::text,
		       COALESCE(NULLIF(u.name, ''), u.email) AS rater_name,
		       r.tester_id::text, r.score, r.comment, r.created_at
		FROM tester_ratings r
		JOIN projects p ON p.id = r.project_id
		JOIN users u ON u.id = r.rater_id
		WHERE r.tester_id = $1
		ORDER BY r.created_at DESC
	`, testerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.TesterRating
	for rows.Next() {
		var r model.TesterRating
		if err := rows.Scan(
			&r.ID, &r.ProjectID, &r.ProjectName, &r.RaterID, &r.RaterName,
			&r.TesterID, &r.Score, &r.Comment, &r.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// CountPendingTesterInvitations returns how many pending invites a user has.
func (s *Store) CountPendingTesterInvitations(ctx context.Context, userID string) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM tester_invitations
		WHERE to_user_id = $1 AND status = 'pending'
	`, userID).Scan(&n)
	return n, err
}
