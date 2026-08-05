package store

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func clampAdminPage(limit, offset int) (int, int) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}

// AdminOverview returns platform-wide KPI counts and recent activity.
func (s *Store) AdminOverview(ctx context.Context) (model.AdminOverview, error) {
	var o model.AdminOverview

	type countQuery struct {
		dest *int
		sql  string
	}
	queries := []countQuery{
		{&o.UsersTotal, `SELECT count(*)::int FROM users`},
		{&o.UsersLast7Days, `SELECT count(*)::int FROM users WHERE created_at >= now() - interval '7 days'`},
		{&o.UsersLast30Days, `SELECT count(*)::int FROM users WHERE created_at >= now() - interval '30 days'`},
		{&o.ProjectsTotal, `SELECT count(*)::int FROM projects`},
		{&o.FeedbackTotal, `SELECT count(*)::int FROM feedback`},
		{&o.FeedbackLast7Days, `SELECT count(*)::int FROM feedback WHERE created_at >= now() - interval '7 days'`},
		{&o.FeedbackLast30Days, `SELECT count(*)::int FROM feedback WHERE created_at >= now() - interval '30 days'`},
		{&o.BugsTotal, `SELECT count(*)::int FROM structured_bugs`},
		{&o.SwapsPending, `SELECT count(*)::int FROM test_swaps WHERE status = 'pending'`},
		{&o.SwapsAccepted, `SELECT count(*)::int FROM test_swaps WHERE status = 'accepted'`},
		{&o.SwapsFulfilled, `SELECT count(*)::int FROM test_swaps WHERE status = 'fulfilled'`},
		{&o.SwapsDeclined, `SELECT count(*)::int FROM test_swaps WHERE status = 'declined'`},
		{&o.SwapsCancelled, `SELECT count(*)::int FROM test_swaps WHERE status = 'cancelled'`},
		{&o.SubsPro, `SELECT count(*)::int FROM subscriptions WHERE plan = 'pro' AND status IN ('active', 'trialing', 'past_due')`},
	}
	for _, q := range queries {
		if err := s.pool.QueryRow(ctx, q.sql).Scan(q.dest); err != nil {
			return o, err
		}
	}

	// Free = users without an active Pro subscription row matching above.
	o.SubsFree = o.UsersTotal - o.SubsPro
	if o.SubsFree < 0 {
		o.SubsFree = 0
	}

	activity, err := s.adminRecentActivity(ctx, 20)
	if err != nil {
		return o, err
	}
	o.RecentActivity = activity
	return o, nil
}

func (s *Store) adminRecentActivity(ctx context.Context, limit int) ([]model.AdminActivity, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT a.id::text, a.project_id::text, p.name,
		       a.actor_id::text, u.name,
		       a.type, a.subject, a.note, a.created_at
		FROM activity a
		JOIN projects p ON p.id = a.project_id
		JOIN users u ON u.id = a.actor_id
		ORDER BY a.created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.AdminActivity, 0)
	for rows.Next() {
		var a model.AdminActivity
		if err := rows.Scan(
			&a.ID, &a.ProjectID, &a.ProjectName,
			&a.ActorID, &a.ActorName,
			&a.Type, &a.Subject, &a.Note, &a.CreatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, a)
	}
	return items, rows.Err()
}

// AdminListUsers returns a paginated user list with plan and project counts.
func (s *Store) AdminListUsers(ctx context.Context, q string, limit, offset int) ([]model.AdminUserRow, int, error) {
	limit, offset = clampAdminPage(limit, offset)
	q = strings.TrimSpace(q)

	var (
		total int
		rows  pgx.Rows
		err   error
	)
	if q == "" {
		err = s.pool.QueryRow(ctx, `SELECT count(*)::int FROM users`).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, `
			SELECT u.id::text, u.email, u.name, u.avatar_hue, u.created_at,
			       COALESCE(sub.plan, 'free') AS plan,
			       (SELECT count(*)::int FROM project_members pm WHERE pm.user_id = u.id) AS project_count
			FROM users u
			LEFT JOIN subscriptions sub ON sub.user_id = u.id
			ORDER BY u.created_at DESC
			LIMIT $1 OFFSET $2
		`, limit, offset)
	} else {
		pattern := "%" + q + "%"
		err = s.pool.QueryRow(ctx, `
			SELECT count(*)::int FROM users
			WHERE email ILIKE $1 OR name ILIKE $1
		`, pattern).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, `
			SELECT u.id::text, u.email, u.name, u.avatar_hue, u.created_at,
			       COALESCE(sub.plan, 'free') AS plan,
			       (SELECT count(*)::int FROM project_members pm WHERE pm.user_id = u.id) AS project_count
			FROM users u
			LEFT JOIN subscriptions sub ON sub.user_id = u.id
			WHERE u.email ILIKE $1 OR u.name ILIKE $1
			ORDER BY u.created_at DESC
			LIMIT $2 OFFSET $3
		`, pattern, limit, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]model.AdminUserRow, 0)
	for rows.Next() {
		var row model.AdminUserRow
		if err := rows.Scan(
			&row.ID, &row.Email, &row.Name, &row.AvatarHue, &row.CreatedAt,
			&row.Plan, &row.ProjectCount,
		); err != nil {
			return nil, 0, err
		}
		items = append(items, row)
	}
	return items, total, rows.Err()
}

// AdminGetUser returns a full ops user detail.
func (s *Store) AdminGetUser(ctx context.Context, userID string) (model.AdminUserDetail, error) {
	user, err := s.GetUser(ctx, userID)
	if err != nil {
		return model.AdminUserDetail{}, err
	}
	sub, err := s.GetSubscription(ctx, userID)
	if err != nil {
		return model.AdminUserDetail{}, err
	}

	projRows, err := s.pool.Query(ctx, `
		SELECT p.id::text, p.name, pm.role
		FROM project_members pm
		JOIN projects p ON p.id = pm.project_id
		WHERE pm.user_id = $1
		ORDER BY p.created_at DESC
	`, userID)
	if err != nil {
		return model.AdminUserDetail{}, err
	}
	defer projRows.Close()
	projects := make([]model.AdminUserProject, 0)
	for projRows.Next() {
		var p model.AdminUserProject
		if err := projRows.Scan(&p.ID, &p.Name, &p.Role); err != nil {
			return model.AdminUserDetail{}, err
		}
		projects = append(projects, p)
	}
	if err := projRows.Err(); err != nil {
		return model.AdminUserDetail{}, err
	}

	feedback, err := s.adminFeedbackForAuthor(ctx, userID, 10)
	if err != nil {
		return model.AdminUserDetail{}, err
	}

	swaps, err := s.adminSwapsForUser(ctx, userID, 10)
	if err != nil {
		return model.AdminUserDetail{}, err
	}

	return model.AdminUserDetail{
		User:           user,
		Subscription:   sub,
		Projects:       projects,
		RecentFeedback: feedback,
		RecentSwaps:    swaps,
	}, nil
}

func (s *Store) adminFeedbackForAuthor(ctx context.Context, authorID string, limit int) ([]model.AdminFeedbackRow, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.id::text, f.project_id::text, p.name,
		       f.author_id::text, u.name, f.title, f.body, f.created_at
		FROM feedback f
		JOIN projects p ON p.id = f.project_id
		JOIN users u ON u.id = f.author_id
		WHERE f.author_id = $1
		ORDER BY f.created_at DESC
		LIMIT $2
	`, authorID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanAdminFeedbackRows(rows)
}

func (s *Store) adminSwapsForUser(ctx context.Context, userID string, limit int) ([]model.TestSwap, error) {
	rows, err := s.pool.Query(ctx, testSwapSelect+`
		WHERE s.from_user_id = $1 OR s.to_user_id = $1
		ORDER BY s.created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.TestSwap, 0)
	for rows.Next() {
		sw, err := scanTestSwap(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, sw)
	}
	return items, rows.Err()
}

// AdminListProjects returns a paginated project list.
func (s *Store) AdminListProjects(ctx context.Context, q string, limit, offset int) ([]model.AdminProjectRow, int, error) {
	limit, offset = clampAdminPage(limit, offset)
	q = strings.TrimSpace(q)

	var (
		total int
		rows  pgx.Rows
		err   error
	)
	baseSelect := `
		SELECT p.id::text, p.name, p.creator_id::text, cu.name, cu.email, p.created_at,
		       (SELECT count(*)::int FROM project_members pm WHERE pm.project_id = p.id) AS member_count,
		       (SELECT count(*)::int FROM project_members pm WHERE pm.project_id = p.id AND pm.role = 'tester') AS tester_count,
		       (SELECT count(*)::int FROM feedback f WHERE f.project_id = p.id) AS feedback_count
		FROM projects p
		JOIN users cu ON cu.id = p.creator_id`

	if q == "" {
		err = s.pool.QueryRow(ctx, `SELECT count(*)::int FROM projects`).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, baseSelect+`
			ORDER BY p.created_at DESC
			LIMIT $1 OFFSET $2
		`, limit, offset)
	} else {
		pattern := "%" + q + "%"
		err = s.pool.QueryRow(ctx, `
			SELECT count(*)::int FROM projects WHERE name ILIKE $1
		`, pattern).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, baseSelect+`
			WHERE p.name ILIKE $1
			ORDER BY p.created_at DESC
			LIMIT $2 OFFSET $3
		`, pattern, limit, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]model.AdminProjectRow, 0)
	for rows.Next() {
		var row model.AdminProjectRow
		if err := rows.Scan(
			&row.ID, &row.Name, &row.CreatorID, &row.CreatorName, &row.CreatorEmail, &row.CreatedAt,
			&row.MemberCount, &row.TesterCount, &row.FeedbackCount,
		); err != nil {
			return nil, 0, err
		}
		items = append(items, row)
	}
	return items, total, rows.Err()
}

// AdminGetProject returns a full ops project detail.
func (s *Store) AdminGetProject(ctx context.Context, projectID string) (model.AdminProjectDetail, error) {
	project, err := s.GetProject(ctx, projectID)
	if err != nil {
		return model.AdminProjectDetail{}, err
	}

	var feedbackCount, bugCount int
	if err := s.pool.QueryRow(ctx, `SELECT count(*)::int FROM feedback WHERE project_id = $1`, projectID).Scan(&feedbackCount); err != nil {
		return model.AdminProjectDetail{}, err
	}
	if err := s.pool.QueryRow(ctx, `SELECT count(*)::int FROM structured_bugs WHERE project_id = $1`, projectID).Scan(&bugCount); err != nil {
		return model.AdminProjectDetail{}, err
	}

	feedback, err := s.adminFeedbackForProject(ctx, projectID, 15)
	if err != nil {
		return model.AdminProjectDetail{}, err
	}

	rows, err := s.pool.Query(ctx, `
		SELECT a.id::text, a.project_id::text, p.name,
		       a.actor_id::text, u.name,
		       a.type, a.subject, a.note, a.created_at
		FROM activity a
		JOIN projects p ON p.id = a.project_id
		JOIN users u ON u.id = a.actor_id
		WHERE a.project_id = $1
		ORDER BY a.created_at DESC
		LIMIT 15
	`, projectID)
	if err != nil {
		return model.AdminProjectDetail{}, err
	}
	defer rows.Close()
	activity := make([]model.AdminActivity, 0)
	for rows.Next() {
		var a model.AdminActivity
		if err := rows.Scan(
			&a.ID, &a.ProjectID, &a.ProjectName,
			&a.ActorID, &a.ActorName,
			&a.Type, &a.Subject, &a.Note, &a.CreatedAt,
		); err != nil {
			return model.AdminProjectDetail{}, err
		}
		activity = append(activity, a)
	}
	if err := rows.Err(); err != nil {
		return model.AdminProjectDetail{}, err
	}

	return model.AdminProjectDetail{
		Project:        project,
		FeedbackCount:  feedbackCount,
		BugCount:       bugCount,
		RecentFeedback: feedback,
		RecentActivity: activity,
	}, nil
}

func (s *Store) adminFeedbackForProject(ctx context.Context, projectID string, limit int) ([]model.AdminFeedbackRow, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.id::text, f.project_id::text, p.name,
		       f.author_id::text, u.name, f.title, f.body, f.created_at
		FROM feedback f
		JOIN projects p ON p.id = f.project_id
		JOIN users u ON u.id = f.author_id
		WHERE f.project_id = $1
		ORDER BY f.created_at DESC
		LIMIT $2
	`, projectID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanAdminFeedbackRows(rows)
}

// AdminListFeedback returns a cross-project feedback feed.
func (s *Store) AdminListFeedback(ctx context.Context, q string, limit, offset int) ([]model.AdminFeedbackRow, int, error) {
	limit, offset = clampAdminPage(limit, offset)
	q = strings.TrimSpace(q)

	var (
		total int
		rows  pgx.Rows
		err   error
	)
	if q == "" {
		err = s.pool.QueryRow(ctx, `SELECT count(*)::int FROM feedback`).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, `
			SELECT f.id::text, f.project_id::text, p.name,
			       f.author_id::text, u.name, f.title, f.body, f.created_at
			FROM feedback f
			JOIN projects p ON p.id = f.project_id
			JOIN users u ON u.id = f.author_id
			ORDER BY f.created_at DESC
			LIMIT $1 OFFSET $2
		`, limit, offset)
	} else {
		pattern := "%" + q + "%"
		err = s.pool.QueryRow(ctx, `
			SELECT count(*)::int
			FROM feedback f
			JOIN projects p ON p.id = f.project_id
			JOIN users u ON u.id = f.author_id
			WHERE f.body ILIKE $1 OR COALESCE(f.title, '') ILIKE $1
			   OR p.name ILIKE $1 OR u.name ILIKE $1
		`, pattern).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, `
			SELECT f.id::text, f.project_id::text, p.name,
			       f.author_id::text, u.name, f.title, f.body, f.created_at
			FROM feedback f
			JOIN projects p ON p.id = f.project_id
			JOIN users u ON u.id = f.author_id
			WHERE f.body ILIKE $1 OR COALESCE(f.title, '') ILIKE $1
			   OR p.name ILIKE $1 OR u.name ILIKE $1
			ORDER BY f.created_at DESC
			LIMIT $2 OFFSET $3
		`, pattern, limit, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items, err := scanAdminFeedbackRows(rows)
	return items, total, err
}

func scanAdminFeedbackRows(rows pgx.Rows) ([]model.AdminFeedbackRow, error) {
	items := make([]model.AdminFeedbackRow, 0)
	for rows.Next() {
		var row model.AdminFeedbackRow
		if err := rows.Scan(
			&row.ID, &row.ProjectID, &row.ProjectName,
			&row.AuthorID, &row.AuthorName, &row.Title, &row.Body, &row.CreatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, row)
	}
	return items, rows.Err()
}

// AdminListSwaps returns a paginated swap list with optional status filter.
func (s *Store) AdminListSwaps(ctx context.Context, status string, limit, offset int) ([]model.TestSwap, int, error) {
	limit, offset = clampAdminPage(limit, offset)
	status = strings.TrimSpace(strings.ToLower(status))

	var (
		total int
		rows  pgx.Rows
		err   error
	)
	if status == "" {
		err = s.pool.QueryRow(ctx, `SELECT count(*)::int FROM test_swaps`).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, testSwapSelect+`
			ORDER BY s.created_at DESC
			LIMIT $1 OFFSET $2
		`, limit, offset)
	} else {
		err = s.pool.QueryRow(ctx, `SELECT count(*)::int FROM test_swaps WHERE status = $1`, status).Scan(&total)
		if err != nil {
			return nil, 0, err
		}
		rows, err = s.pool.Query(ctx, testSwapSelect+`
			WHERE s.status = $1
			ORDER BY s.created_at DESC
			LIMIT $2 OFFSET $3
		`, status, limit, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]model.TestSwap, 0)
	for rows.Next() {
		sw, err := scanTestSwap(rows)
		if err != nil {
			return nil, 0, err
		}
		items = append(items, sw)
	}
	return items, total, rows.Err()
}
