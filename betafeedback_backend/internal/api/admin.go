package api

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

func adminPageParams(r *http.Request) (limit, offset int) {
	limit, _ = strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ = strconv.Atoi(r.URL.Query().Get("offset"))
	return limit, offset
}

func writeAdminList(w http.ResponseWriter, items any, total, limit, offset int) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items":  items,
		"total":  total,
		"limit":  limit,
		"offset": offset,
	})
}

func (s *Server) adminOverview(w http.ResponseWriter, r *http.Request, _ string) {
	overview, err := s.store.AdminOverview(r.Context())
	if err != nil {
		s.serverError(w, "admin overview", err)
		return
	}
	writeJSON(w, http.StatusOK, overview)
}

func (s *Server) adminMe(w http.ResponseWriter, r *http.Request, userID string) {
	user, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		s.serverError(w, "admin me", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id":    user.ID,
		"email": user.Email,
		"name":  user.Name,
		"admin": true,
	})
}

func (s *Server) adminListUsers(w http.ResponseWriter, r *http.Request, _ string) {
	limit, offset := adminPageParams(r)
	q := r.URL.Query().Get("q")
	items, total, err := s.store.AdminListUsers(r.Context(), q, limit, offset)
	if err != nil {
		s.serverError(w, "admin list users", err)
		return
	}
	writeAdminList(w, items, total, limit, offset)
}

func (s *Server) adminGetUser(w http.ResponseWriter, r *http.Request, _ string) {
	id := r.PathValue("id")
	detail, err := s.store.AdminGetUser(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "admin get user", err)
		return
	}
	writeJSON(w, http.StatusOK, detail)
}

func (s *Server) adminListProjects(w http.ResponseWriter, r *http.Request, _ string) {
	limit, offset := adminPageParams(r)
	q := r.URL.Query().Get("q")
	items, total, err := s.store.AdminListProjects(r.Context(), q, limit, offset)
	if err != nil {
		s.serverError(w, "admin list projects", err)
		return
	}
	writeAdminList(w, items, total, limit, offset)
}

func (s *Server) adminGetProject(w http.ResponseWriter, r *http.Request, _ string) {
	id := r.PathValue("id")
	detail, err := s.store.AdminGetProject(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "project not found")
			return
		}
		s.serverError(w, "admin get project", err)
		return
	}
	writeJSON(w, http.StatusOK, detail)
}

func (s *Server) adminListFeedback(w http.ResponseWriter, r *http.Request, _ string) {
	limit, offset := adminPageParams(r)
	q := r.URL.Query().Get("q")
	items, total, err := s.store.AdminListFeedback(r.Context(), q, limit, offset)
	if err != nil {
		s.serverError(w, "admin list feedback", err)
		return
	}
	writeAdminList(w, items, total, limit, offset)
}

func (s *Server) adminListSwaps(w http.ResponseWriter, r *http.Request, _ string) {
	limit, offset := adminPageParams(r)
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	items, total, err := s.store.AdminListSwaps(r.Context(), status, limit, offset)
	if err != nil {
		s.serverError(w, "admin list swaps", err)
		return
	}
	writeAdminList(w, items, total, limit, offset)
}
