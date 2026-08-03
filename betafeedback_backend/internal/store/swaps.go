package store

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

const maxPendingOutgoingSwaps = 5

const testSwapSelect = `
		SELECT
			s.id::text,
			s.from_user_id::text, fu.name,
			s.to_user_id::text, tu.name,
			s.from_project_id::text, fp.name, fp.logo_url,
			s.to_project_id::text, tp.name, tp.logo_url,
			s.message, s.status, s.created_at, s.responded_at, s.fulfilled_at
		FROM test_swaps s
		JOIN users fu ON fu.id = s.from_user_id
		JOIN users tu ON tu.id = s.to_user_id
		JOIN projects fp ON fp.id = s.from_project_id
		JOIN projects tp ON tp.id = s.to_project_id`

func scanTestSwap(row pgx.Row) (model.TestSwap, error) {
	var sw model.TestSwap
	err := row.Scan(
		&sw.ID,
		&sw.FromUserID, &sw.FromUserName,
		&sw.ToUserID, &sw.ToUserName,
		&sw.FromProjectID, &sw.FromProjectName, &sw.FromProjectLogo,
		&sw.ToProjectID, &sw.ToProjectName, &sw.ToProjectLogo,
		&sw.Message, &sw.Status, &sw.CreatedAt, &sw.RespondedAt, &sw.FulfilledAt,
	)
	return sw, err
}

// GetTestSwap loads a single swap with project/user names.
func (s *Store) GetTestSwap(ctx context.Context, id string) (model.TestSwap, error) {
	row := s.pool.QueryRow(ctx, testSwapSelect+` WHERE s.id = $1`, id)
	sw, err := scanTestSwap(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TestSwap{}, ErrNotFound
	}
	return sw, err
}

// ListSwapPartners returns creators open to swaps who own at least one project.
// When projectID is set, flags pending swaps against that project and excludes
// users already members of it.
func (s *Store) ListSwapPartners(ctx context.Context, viewerID, projectID, query string, limit int) ([]model.SwapPartner, error) {
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
			CASE WHEN $2::uuid IS NOT NULL THEN EXISTS (
				SELECT 1 FROM test_swaps ts
				WHERE ts.status = 'pending'
				  AND (
				    (ts.from_project_id = $2 AND ts.to_user_id = u.id)
				    OR (ts.to_project_id = $2 AND ts.from_user_id = u.id)
				  )
			) ELSE false END AS swap_pending
		FROM users u
		LEFT JOIN tester_ratings r ON r.tester_id = u.id
		WHERE u.open_to_swap = true
		  AND u.id <> $1
		  AND EXISTS (SELECT 1 FROM projects p WHERE p.creator_id = u.id)
		  AND ($3 = '' OR u.name ILIKE '%' || $3 || '%'
		       OR u.email ILIKE '%' || $3 || '%'
		       OR u.tester_bio ILIKE '%' || $3 || '%')
		  AND ($2::uuid IS NULL OR NOT EXISTS (
		        SELECT 1 FROM project_members pm
		        WHERE pm.project_id = $2 AND pm.user_id = u.id
		      ))
		GROUP BY u.id
		ORDER BY rating_avg DESC NULLS LAST, rating_count DESC, u.name ASC
		LIMIT $4
	`, viewerID, nullUUID(projectID), q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.SwapPartner, 0)
	for rows.Next() {
		var p model.SwapPartner
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Email, &p.AvatarHue, &p.TesterBio,
			&p.RatingAvg, &p.RatingCount, &p.SwapPending,
		); err != nil {
			return nil, err
		}
		projects, err := s.listCreatorSwapProjects(ctx, p.ID, projectID)
		if err != nil {
			return nil, err
		}
		p.Projects = projects
		if len(p.Projects) == 0 {
			continue
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) listCreatorSwapProjects(ctx context.Context, creatorID, excludeProjectID string) ([]model.SwapProject, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, name, logo_url
		FROM projects
		WHERE creator_id = $1
		  AND ($2::uuid IS NULL OR id <> $2)
		ORDER BY created_at DESC
		LIMIT 20
	`, creatorID, nullUUID(excludeProjectID))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.SwapProject, 0)
	for rows.Next() {
		var p model.SwapProject
		if err := rows.Scan(&p.ID, &p.Name, &p.LogoURL); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// CreateTestSwap proposes a reciprocal test between two creator-owned projects.
func (s *Store) CreateTestSwap(ctx context.Context, fromUserID, fromProjectID, toProjectID, message string) (model.TestSwap, error) {
	var fromCreator, toCreator string
	var toOpen bool
	err := s.pool.QueryRow(ctx, `
		SELECT p.creator_id::text FROM projects p WHERE p.id = $1
	`, fromProjectID).Scan(&fromCreator)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TestSwap{}, ErrNotFound
	}
	if err != nil {
		return model.TestSwap{}, err
	}
	if fromCreator != fromUserID {
		return model.TestSwap{}, ErrForbidden
	}

	err = s.pool.QueryRow(ctx, `
		SELECT p.creator_id::text, u.open_to_swap
		FROM projects p
		JOIN users u ON u.id = p.creator_id
		WHERE p.id = $1
	`, toProjectID).Scan(&toCreator, &toOpen)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TestSwap{}, ErrNotFound
	}
	if err != nil {
		return model.TestSwap{}, err
	}
	if toCreator == fromUserID {
		return model.TestSwap{}, fmt.Errorf("%w: cannot swap with yourself", ErrConflict)
	}
	if !toOpen {
		return model.TestSwap{}, fmt.Errorf("%w: user is not open to swaps", ErrConflict)
	}

	var fromPending int
	if err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM test_swaps
		WHERE from_user_id = $1 AND status = 'pending'
	`, fromUserID).Scan(&fromPending); err != nil {
		return model.TestSwap{}, err
	}
	if fromPending >= maxPendingOutgoingSwaps {
		return model.TestSwap{}, fmt.Errorf("%w: too many pending swaps", ErrConflict)
	}

	var alreadyMember bool
	if err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM project_members WHERE project_id = $1 AND user_id = $2
		) OR EXISTS (
			SELECT 1 FROM project_members WHERE project_id = $3 AND user_id = $4
		)
	`, fromProjectID, toCreator, toProjectID, fromUserID).Scan(&alreadyMember); err != nil {
		return model.TestSwap{}, err
	}
	if alreadyMember {
		return model.TestSwap{}, fmt.Errorf("%w: already members of one of these projects", ErrConflict)
	}

	row := s.pool.QueryRow(ctx, `
		INSERT INTO test_swaps (from_user_id, to_user_id, from_project_id, to_project_id, message)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id::text
	`, fromUserID, toCreator, fromProjectID, toProjectID, message)
	var id string
	if err := row.Scan(&id); err != nil {
		if isUniqueViolation(err) {
			return model.TestSwap{}, fmt.Errorf("%w: swap already pending", ErrConflict)
		}
		return model.TestSwap{}, err
	}

	fromName, _ := s.ProjectName(ctx, fromProjectID)
	toName, _ := s.ProjectName(ctx, toProjectID)
	title := "Test-for-test proposal"
	body := fmt.Sprintf("Swap: test %s and they'll test %s", fromName, toName)
	_, _ = s.pool.Exec(ctx, `
		INSERT INTO notifications (recipient_id, project_id, kind, title, body)
		VALUES ($1, $2, 'swap_invite', $3, $4)
	`, toCreator, fromProjectID, title, body)

	return s.GetTestSwap(ctx, id)
}

// ListMyTestSwaps returns swaps involving the user, pending first.
func (s *Store) ListMyTestSwaps(ctx context.Context, userID string) ([]model.TestSwap, error) {
	rows, err := s.pool.Query(ctx, testSwapSelect+`
		WHERE s.from_user_id = $1 OR s.to_user_id = $1
		ORDER BY
			CASE WHEN s.status = 'pending' THEN 0
			     WHEN s.status = 'accepted' THEN 1
			     ELSE 2 END,
			s.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TestSwap, 0)
	for rows.Next() {
		sw, err := scanTestSwap(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, sw)
	}
	return out, rows.Err()
}

// CountPendingIncomingSwaps returns pending swaps addressed to the user.
func (s *Store) CountPendingIncomingSwaps(ctx context.Context, userID string) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM test_swaps
		WHERE to_user_id = $1 AND status = 'pending'
	`, userID).Scan(&n)
	return n, err
}

// AcceptTestSwap adds each creator as a tester on the other's project.
func (s *Store) AcceptTestSwap(ctx context.Context, swapID, userID string) (model.TestSwap, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.TestSwap{}, err
	}
	defer tx.Rollback(ctx)

	var fromUserID, toUserID, fromProjectID, toProjectID, status string
	var fromCreator, toCreator string
	err = tx.QueryRow(ctx, `
		SELECT s.from_user_id::text, s.to_user_id::text,
		       s.from_project_id::text, s.to_project_id::text, s.status,
		       fp.creator_id::text, tp.creator_id::text
		FROM test_swaps s
		JOIN projects fp ON fp.id = s.from_project_id
		JOIN projects tp ON tp.id = s.to_project_id
		WHERE s.id = $1
		FOR UPDATE OF s
	`, swapID).Scan(&fromUserID, &toUserID, &fromProjectID, &toProjectID, &status, &fromCreator, &toCreator)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TestSwap{}, ErrNotFound
	}
	if err != nil {
		return model.TestSwap{}, err
	}
	if toUserID != userID {
		return model.TestSwap{}, ErrForbidden
	}
	if status != "pending" {
		return model.TestSwap{}, fmt.Errorf("%w: swap is no longer pending", ErrConflict)
	}
	if fromCreator != fromUserID || toCreator != toUserID {
		return model.TestSwap{}, fmt.Errorf("%w: project ownership changed", ErrConflict)
	}

	tag, err := tx.Exec(ctx, `
		UPDATE test_swaps
		SET status = 'accepted', responded_at = now()
		WHERE id = $1 AND status = 'pending'
	`, swapID)
	if err != nil {
		return model.TestSwap{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.TestSwap{}, fmt.Errorf("%w: swap is no longer pending", ErrConflict)
	}

	// Proposer joins counterparty project; counterparty joins proposer's project.
	if _, err = tx.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, 'tester')
		ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role
	`, toProjectID, fromUserID); err != nil {
		return model.TestSwap{}, err
	}
	if _, err = tx.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, 'tester')
		ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role
	`, fromProjectID, toUserID); err != nil {
		return model.TestSwap{}, err
	}

	fromName, _ := s.ProjectName(ctx, fromProjectID)
	toName, _ := s.ProjectName(ctx, toProjectID)
	title := "Swap accepted"
	body := fmt.Sprintf("You're now testers on %s and %s", fromName, toName)
	_, _ = tx.Exec(ctx, `
		INSERT INTO notifications (recipient_id, project_id, kind, title, body)
		VALUES ($1, $2, 'swap_accepted', $3, $4)
	`, fromUserID, toProjectID, title, body)

	if err = tx.Commit(ctx); err != nil {
		return model.TestSwap{}, err
	}
	return s.GetTestSwap(ctx, swapID)
}

// DeclineTestSwap rejects a pending swap (recipient only).
func (s *Store) DeclineTestSwap(ctx context.Context, swapID, userID string) (model.TestSwap, error) {
	return s.respondPendingSwap(ctx, swapID, userID, "declined", true)
}

// CancelTestSwap cancels a pending swap (proposer only).
func (s *Store) CancelTestSwap(ctx context.Context, swapID, userID string) (model.TestSwap, error) {
	return s.respondPendingSwap(ctx, swapID, userID, "cancelled", false)
}

func (s *Store) respondPendingSwap(ctx context.Context, swapID, userID, status string, asRecipient bool) (model.TestSwap, error) {
	var fromUserID, toUserID, current string
	err := s.pool.QueryRow(ctx, `
		SELECT from_user_id::text, to_user_id::text, status
		FROM test_swaps WHERE id = $1
	`, swapID).Scan(&fromUserID, &toUserID, &current)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.TestSwap{}, ErrNotFound
	}
	if err != nil {
		return model.TestSwap{}, err
	}
	if asRecipient {
		if toUserID != userID {
			return model.TestSwap{}, ErrForbidden
		}
	} else if fromUserID != userID {
		return model.TestSwap{}, ErrForbidden
	}
	if current != "pending" {
		return model.TestSwap{}, fmt.Errorf("%w: swap is no longer pending", ErrConflict)
	}

	tag, err := s.pool.Exec(ctx, `
		UPDATE test_swaps
		SET status = $2, responded_at = now()
		WHERE id = $1 AND status = 'pending'
	`, swapID, status)
	if err != nil {
		return model.TestSwap{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.TestSwap{}, fmt.Errorf("%w: swap is no longer pending", ErrConflict)
	}
	return s.GetTestSwap(ctx, swapID)
}

// MaybeFulfillSwapsForFeedback marks accepted swaps as fulfilled when both
// parties have submitted at least one tester_message on the counterpart project.
func (s *Store) MaybeFulfillSwapsForFeedback(ctx context.Context, projectID, authorID string) ([]model.TestSwap, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, from_user_id::text, to_user_id::text,
		       from_project_id::text, to_project_id::text
		FROM test_swaps
		WHERE status = 'accepted'
		  AND (
		    (from_project_id = $1 AND to_user_id = $2)
		    OR (to_project_id = $1 AND from_user_id = $2)
		  )
	`, projectID, authorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type candidate struct {
		id, fromUser, toUser, fromProject, toProject string
	}
	var cands []candidate
	for rows.Next() {
		var c candidate
		if err := rows.Scan(&c.id, &c.fromUser, &c.toUser, &c.fromProject, &c.toProject); err != nil {
			return nil, err
		}
		cands = append(cands, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	fulfilled := make([]model.TestSwap, 0)
	for _, c := range cands {
		var fromDone, toDone bool
		if err := s.pool.QueryRow(ctx, `
			SELECT EXISTS (
				SELECT 1 FROM feedback
				WHERE project_id = $1 AND author_id = $2
			)
		`, c.toProject, c.fromUser).Scan(&fromDone); err != nil {
			return nil, err
		}
		if err := s.pool.QueryRow(ctx, `
			SELECT EXISTS (
				SELECT 1 FROM feedback
				WHERE project_id = $1 AND author_id = $2
			)
		`, c.fromProject, c.toUser).Scan(&toDone); err != nil {
			return nil, err
		}
		if !fromDone || !toDone {
			continue
		}
		tag, err := s.pool.Exec(ctx, `
			UPDATE test_swaps
			SET status = 'fulfilled', fulfilled_at = now()
			WHERE id = $1 AND status = 'accepted'
		`, c.id)
		if err != nil {
			return nil, err
		}
		if tag.RowsAffected() == 0 {
			continue
		}
		sw, err := s.GetTestSwap(ctx, c.id)
		if err != nil {
			return nil, err
		}
		title := "Swap complete"
		body := fmt.Sprintf("Both of you filed feedback on %s and %s", sw.FromProjectName, sw.ToProjectName)
		_, _ = s.pool.Exec(ctx, `
			INSERT INTO notifications (recipient_id, project_id, kind, title, body)
			VALUES ($1, $2, 'swap_fulfilled', $3, $4),
			       ($5, $6, 'swap_fulfilled', $3, $4)
		`, sw.FromUserID, sw.ToProjectID, title, body, sw.ToUserID, sw.FromProjectID)
		fulfilled = append(fulfilled, sw)
	}
	return fulfilled, nil
}
