package api

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) listProjects(w http.ResponseWriter, r *http.Request, userID string) {
	projects, err := s.store.ListProjectsForUser(r.Context(), userID)
	if err != nil {
		s.serverError(w, "list projects", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"projects": projects})
}

type createProjectRequest struct {
	Name               string               `json:"name"`
	Description        string               `json:"description"`
	AppLink            string               `json:"app_link"`
	GoogleGroupJoinURL string               `json:"google_group_join_url"`
	PlatformLinks      []model.PlatformLink `json:"platform_links"`
	MemberNotes        string               `json:"member_notes"`
}

// sanitizePlatformLinks trims and drops empty or duplicate-platform entries so
// the stored array holds at most one link per platform.
func sanitizePlatformLinks(in []model.PlatformLink) []model.PlatformLink {
	out := make([]model.PlatformLink, 0, len(in))
	seen := make(map[string]bool, len(in))
	for _, l := range in {
		platform := strings.TrimSpace(l.Platform)
		url := strings.TrimSpace(l.URL)
		if platform == "" || url == "" || seen[platform] {
			continue
		}
		seen[platform] = true
		out = append(out, model.PlatformLink{Platform: platform, URL: url})
	}
	return out
}

func (s *Server) createProject(w http.ResponseWriter, r *http.Request, userID string) {
	can, err := s.store.CanUserCreateProject(r.Context(), userID)
	if err != nil {
		s.serverError(w, "check project limit", err)
		return
	}
	if !can {
		writeError(w, http.StatusPaymentRequired,
			fmt.Sprintf("free plan allows %d project — upgrade to Pro for unlimited projects", store.FreeProjectLimit))
		return
	}

	var req createProjectRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}

	project, err := s.store.CreateProject(
		r.Context(), userID, name, strings.TrimSpace(req.Description),
		generateInviteCode(name), optionalString(req.AppLink),
		optionalString(req.GoogleGroupJoinURL),
		sanitizePlatformLinks(req.PlatformLinks),
		strings.TrimSpace(req.MemberNotes),
	)
	if err != nil {
		s.serverError(w, "create project", err)
		return
	}
	writeJSON(w, http.StatusCreated, project)
}

func (s *Server) getProject(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	project, err := s.store.GetProject(r.Context(), id)
	if err != nil {
		s.serverError(w, "get project", err)
		return
	}
	writeJSON(w, http.StatusOK, project)
}

type updateProjectRequest struct {
	LogoURL            *string              `json:"logo_url"`
	GoogleGroupJoinURL *string              `json:"google_group_join_url"`
	PlatformLinks      []model.PlatformLink `json:"platform_links"`
	MemberNotes        *string              `json:"member_notes"`
}

const maxMemberNotesLen = 8000

func validProjectLogoURL(projectID, url string) bool {
	if url == "" {
		return true
	}
	return strings.HasPrefix(url, "/media/"+projectID+"/")
}

func (s *Server) updateProject(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can update the project")
		return
	}

	var req updateProjectRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.LogoURL != nil {
		logoURL := strings.TrimSpace(*req.LogoURL)
		if logoURL != "" && !validProjectLogoURL(id, logoURL) {
			writeError(w, http.StatusBadRequest, "invalid logo_url")
			return
		}
		var stored *string
		if logoURL != "" {
			stored = &logoURL
		}
		if _, err := s.store.UpdateProjectLogo(r.Context(), id, stored); err != nil {
			s.serverError(w, "update project logo", err)
			return
		}
	}

	if req.MemberNotes != nil {
		notes := strings.TrimSpace(*req.MemberNotes)
		if len(notes) > maxMemberNotesLen {
			writeError(w, http.StatusBadRequest,
				fmt.Sprintf("member_notes must be %d characters or fewer", maxMemberNotesLen))
			return
		}
		if _, err := s.store.UpdateProjectMemberNotes(r.Context(), id, notes); err != nil {
			s.serverError(w, "update project notes", err)
			return
		}
	}

	if req.GoogleGroupJoinURL != nil || req.PlatformLinks != nil {
		var links []model.PlatformLink
		if req.PlatformLinks != nil {
			links = sanitizePlatformLinks(req.PlatformLinks)
		} else {
			current, err := s.store.GetProject(r.Context(), id)
			if err != nil {
				s.serverError(w, "get project", err)
				return
			}
			links = current.PlatformLinks
		}
		var groupURL *string
		if req.GoogleGroupJoinURL != nil {
			groupURL = optionalString(strings.TrimSpace(*req.GoogleGroupJoinURL))
		} else {
			current, err := s.store.GetProject(r.Context(), id)
			if err != nil {
				s.serverError(w, "get project", err)
				return
			}
			groupURL = current.GoogleGroupJoinURL
		}
		if _, err := s.store.UpdateProjectDistribution(r.Context(), id, groupURL, links); err != nil {
			s.serverError(w, "update project distribution", err)
			return
		}
	}

	project, err := s.store.GetProject(r.Context(), id)
	if err != nil {
		s.serverError(w, "get project", err)
		return
	}
	writeJSON(w, http.StatusOK, project)
}

func derefString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func (s *Server) listTesterEmails(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can export tester emails")
		return
	}

	emails, err := s.store.ListTesterEmails(r.Context(), id)
	if err != nil {
		s.serverError(w, "list tester emails", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"emails": emails})
}

type addMemberRequest struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Role  string `json:"role"`
}

func (s *Server) addMember(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can invite members")
		return
	}

	var req addMemberRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	email := normalizeEmail(req.Email)
	name := strings.TrimSpace(req.Name)
	if name == "" || !validEmail(email) {
		writeError(w, http.StatusBadRequest, "name and a valid email are required")
		return
	}
	if req.Role != "tester" && req.Role != "developer" {
		writeError(w, http.StatusBadRequest, "role must be tester or developer")
		return
	}

	inv, err := s.store.CreateMemberInvitation(
		r.Context(), id, userID, name, email, req.Role, avatarHue(email),
	)
	if err != nil {
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, "invite member", err)
		return
	}

	s.pushToUsers(r.Context(), []string{inv.ToUserID}, id, "member_invite",
		"Project invitation", inv.ProjectName+" invited you to join as a "+inv.Role)
	s.emailMemberInvite(r.Context(), inv)

	writeJSON(w, http.StatusCreated, inv)
}
