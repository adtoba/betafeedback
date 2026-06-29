package api

import (
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
	Name          string               `json:"name"`
	Description   string               `json:"description"`
	AppLink       string               `json:"app_link"`
	PlatformLinks []model.PlatformLink `json:"platform_links"`
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
		sanitizePlatformLinks(req.PlatformLinks),
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
	LogoURL *string `json:"logo_url"`
}

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

	pro, err := s.store.UserIsPro(r.Context(), userID)
	if err != nil {
		s.serverError(w, "check subscription", err)
		return
	}
	if !pro {
		writeError(w, http.StatusPaymentRequired, "custom project logos are available on the Pro plan")
		return
	}

	var req updateProjectRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.LogoURL == nil {
		writeError(w, http.StatusBadRequest, "logo_url is required")
		return
	}
	logoURL := strings.TrimSpace(*req.LogoURL)
	if logoURL != "" && !validProjectLogoURL(id, logoURL) {
		writeError(w, http.StatusBadRequest, "invalid logo_url")
		return
	}

	var stored *string
	if logoURL != "" {
		stored = &logoURL
	}

	project, err := s.store.UpdateProjectLogo(r.Context(), id, stored)
	if err != nil {
		s.serverError(w, "update project", err)
		return
	}
	writeJSON(w, http.StatusOK, project)
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

	member, err := s.store.AddMember(r.Context(), id, name, email, req.Role, avatarHue(email))
	if err != nil {
		s.serverError(w, "add member", err)
		return
	}
	writeJSON(w, http.StatusCreated, member)
}
