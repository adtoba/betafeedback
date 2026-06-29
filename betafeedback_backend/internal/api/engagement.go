package api

import (
	"context"
	"net/http"
	"strings"
)

func (s *Server) listActivity(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	items, err := s.store.ListActivity(r.Context(), id)
	if err != nil {
		s.serverError(w, "list activity", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"activity": items})
}

type createReleaseRequest struct {
	Version string `json:"version"`
	Notes   string `json:"notes"`
}

func (s *Server) listReleases(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	items, err := s.store.ListReleases(r.Context(), id)
	if err != nil {
		s.serverError(w, "list releases", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"releases": items})
}

func (s *Server) createRelease(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can post releases")
		return
	}

	var req createReleaseRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	version := strings.TrimSpace(req.Version)
	if version == "" {
		writeError(w, http.StatusBadRequest, "version is required")
		return
	}

	project, err := s.store.GetProject(r.Context(), id)
	if err != nil {
		s.serverError(w, "load project", err)
		return
	}
	actor, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		s.serverError(w, "load actor", err)
		return
	}

	release, err := s.store.CreateRelease(
		r.Context(), id, userID, actor.Name, project.Name, version, optionalString(req.Notes),
	)
	if err != nil {
		s.serverError(w, "create release", err)
		return
	}
	go s.emailRelease(context.Background(), id, version, optionalString(req.Notes))
	writeJSON(w, http.StatusCreated, release)
}

func (s *Server) listNotifications(w http.ResponseWriter, r *http.Request, userID string) {
	items, err := s.store.ListNotifications(r.Context(), userID)
	if err != nil {
		s.serverError(w, "list notifications", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"notifications": items})
}

func (s *Server) markNotificationsRead(w http.ResponseWriter, r *http.Request, userID string) {
	count, err := s.store.MarkNotificationsRead(r.Context(), userID)
	if err != nil {
		s.serverError(w, "mark notifications read", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"updated": count})
}
