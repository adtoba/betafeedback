package store

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

// decodePlatformLinks unmarshals a jsonb platform_links column, always
// returning a non-nil slice so the API emits [] rather than null.
func decodePlatformLinks(raw []byte) ([]model.PlatformLink, error) {
	links := []model.PlatformLink{}
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &links); err != nil {
			return nil, err
		}
	}
	if links == nil {
		links = []model.PlatformLink{}
	}
	return links, nil
}

// CreateProject inserts a project and registers the creator as a member.
func (s *Store) CreateProject(ctx context.Context, creatorID, name, description, inviteCode string, appLink *string, platformLinks []model.PlatformLink) (model.Project, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Project{}, err
	}
	defer tx.Rollback(ctx)

	if platformLinks == nil {
		platformLinks = []model.PlatformLink{}
	}
	linksJSON, err := json.Marshal(platformLinks)
	if err != nil {
		return model.Project{}, err
	}

	var p model.Project
	var plRaw []byte
	err = tx.QueryRow(ctx, `
		INSERT INTO projects (name, description, creator_id, invite_code, app_link, platform_links)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id::text, name, description, creator_id::text, invite_code, app_link, platform_links, logo_url, created_at
	`, name, description, creatorID, inviteCode, appLink, string(linksJSON)).
		Scan(&p.ID, &p.Name, &p.Description, &p.CreatorID, &p.InviteCode, &p.AppLink, &plRaw, &p.LogoURL, &p.CreatedAt)
	if err != nil {
		return model.Project{}, err
	}
	if p.PlatformLinks, err = decodePlatformLinks(plRaw); err != nil {
		return model.Project{}, err
	}

	if _, err = tx.Exec(ctx,
		`INSERT INTO project_members (project_id, user_id, role) VALUES ($1, $2, 'creator')`,
		p.ID, creatorID,
	); err != nil {
		return model.Project{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.Project{}, err
	}
	p.InviteLink = s.InviteLink(p.InviteCode)
	return p, nil
}

// ListProjectsForUser returns every project the user belongs to, newest first,
// with the summary counts the project cards need.
func (s *Store) ListProjectsForUser(ctx context.Context, userID string) ([]model.Project, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT p.id::text, p.name, p.description, p.creator_id::text, cu.name,
		       p.invite_code, p.app_link, p.platform_links, p.logo_url, p.created_at,
		       (SELECT count(*) FROM project_members t WHERE t.project_id = p.id AND t.role = 'tester'),
		       (SELECT count(*) FROM project_members a WHERE a.project_id = p.id),
		       (SELECT max(created_at) FROM feedback f WHERE f.project_id = p.id),
		       (SELECT max(ts) FROM (
		           SELECT created_at AS ts FROM feedback WHERE project_id = p.id
		           UNION ALL
		           SELECT created_at AS ts FROM activity WHERE project_id = p.id
		       ) recent)
		FROM projects p
		JOIN project_members m ON m.project_id = p.id AND m.user_id = $1
		JOIN users cu ON cu.id = p.creator_id
		ORDER BY p.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	projects := make([]model.Project, 0)
	for rows.Next() {
		var p model.Project
		var plRaw []byte
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.CreatorID, &p.CreatorName,
			&p.InviteCode, &p.AppLink, &plRaw, &p.LogoURL, &p.CreatedAt,
			&p.TesterCount, &p.MemberCount, &p.LatestFeedbackAt, &p.LatestActivityAt); err != nil {
			return nil, err
		}
		if p.PlatformLinks, err = decodePlatformLinks(plRaw); err != nil {
			return nil, err
		}
		p.InviteLink = s.InviteLink(p.InviteCode)
		projects = append(projects, p)
	}
	return projects, rows.Err()
}

// GetProject returns a project with its members attached.
func (s *Store) GetProject(ctx context.Context, id string) (model.Project, error) {
	var p model.Project
	var plRaw []byte
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, name, description, creator_id::text, invite_code, app_link, platform_links, logo_url, created_at
		FROM projects WHERE id = $1
	`, id).Scan(&p.ID, &p.Name, &p.Description, &p.CreatorID, &p.InviteCode, &p.AppLink, &plRaw, &p.LogoURL, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Project{}, ErrNotFound
	}
	if err != nil {
		return model.Project{}, err
	}
	if p.PlatformLinks, err = decodePlatformLinks(plRaw); err != nil {
		return model.Project{}, err
	}
	p.InviteLink = s.InviteLink(p.InviteCode)

	members, err := s.ListMembers(ctx, id)
	if err != nil {
		return model.Project{}, err
	}
	p.Members = members
	p.MemberCount = len(members)
	for _, m := range members {
		switch m.Role {
		case "tester":
			p.TesterCount++
		case "creator":
			p.CreatorName = m.Name
		}
	}
	return p, nil
}

// UpdateProjectLogo sets or clears the project's logo URL.
func (s *Store) UpdateProjectLogo(ctx context.Context, id string, logoURL *string) (model.Project, error) {
	var p model.Project
	var plRaw []byte
	err := s.pool.QueryRow(ctx, `
		UPDATE projects SET logo_url = $2 WHERE id = $1
		RETURNING id::text, name, description, creator_id::text, invite_code, app_link, platform_links, logo_url, created_at
	`, id, logoURL).Scan(&p.ID, &p.Name, &p.Description, &p.CreatorID, &p.InviteCode, &p.AppLink, &plRaw, &p.LogoURL, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.Project{}, ErrNotFound
	}
	if err != nil {
		return model.Project{}, err
	}
	if p.PlatformLinks, err = decodePlatformLinks(plRaw); err != nil {
		return model.Project{}, err
	}
	p.InviteLink = s.InviteLink(p.InviteCode)
	return p, nil
}

// InviteInfo returns the public summary for an invite code, or ErrNotFound if
// no project has that code.
func (s *Store) InviteInfo(ctx context.Context, code string) (model.InviteInfo, error) {
	var info model.InviteInfo
	err := s.pool.QueryRow(ctx, `
		SELECT p.name, cu.name,
		       (SELECT count(*) FROM project_members t WHERE t.project_id = p.id AND t.role = 'tester')
		FROM projects p
		JOIN users cu ON cu.id = p.creator_id
		WHERE p.invite_code = $1
	`, code).Scan(&info.ProjectName, &info.CreatorName, &info.TesterCount)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.InviteInfo{}, ErrNotFound
	}
	if err != nil {
		return model.InviteInfo{}, err
	}
	return info, nil
}

// MemberRole returns the user's role within a project, or ErrNotFound if they
// are not a member.
func (s *Store) MemberRole(ctx context.Context, projectID, userID string) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx,
		`SELECT role FROM project_members WHERE project_id = $1 AND user_id = $2`,
		projectID, userID,
	).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return role, err
}

func (s *Store) ListMembers(ctx context.Context, projectID string) ([]model.Member, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT u.id::text, u.name, u.email, m.role, u.avatar_hue
		FROM project_members m
		JOIN users u ON u.id = m.user_id
		WHERE m.project_id = $1
		ORDER BY
			CASE m.role WHEN 'creator' THEN 0 WHEN 'developer' THEN 1 ELSE 2 END,
			u.name
	`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	members := make([]model.Member, 0)
	for rows.Next() {
		var m model.Member
		if err := rows.Scan(&m.UserID, &m.Name, &m.Email, &m.Role, &m.AvatarHue); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

// AddMember invites a user (creating them if needed) into a project with a role.
func (s *Store) AddMember(ctx context.Context, projectID, name, email, role string, hue int) (model.Member, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Member{}, err
	}
	defer tx.Rollback(ctx)

	var m model.Member
	err = tx.QueryRow(ctx, `
		INSERT INTO users (email, name, avatar_hue)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
		RETURNING id::text, name, email, avatar_hue
	`, email, name, hue).Scan(&m.UserID, &m.Name, &m.Email, &m.AvatarHue)
	if err != nil {
		return model.Member{}, err
	}

	if _, err = tx.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, $3)
		ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role
	`, projectID, m.UserID, role); err != nil {
		return model.Member{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return model.Member{}, err
	}
	m.Role = role
	return m, nil
}
