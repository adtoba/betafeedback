package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) listTestItems(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	items, err := s.store.ListTestItems(r.Context(), id)
	if err != nil {
		s.serverError(w, "list test items", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"test_items": items})
}

type createTestItemRequest struct {
	Title   string `json:"title"`
	Details string `json:"details"`
}

func (s *Server) addTestItem(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "creator" && role != "developer" {
		writeError(w, http.StatusForbidden, "only the creator or a developer can add test items")
		return
	}

	var req createTestItemRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		writeError(w, http.StatusBadRequest, "title is required")
		return
	}

	item, err := s.store.AddTestItem(r.Context(), id, title, optionalString(req.Details), userID)
	if err != nil {
		s.serverError(w, "add test item", err)
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

func (s *Server) removeTestItem(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can manage the test plan")
		return
	}

	if err := s.store.RemoveTestItem(r.Context(), id, r.PathValue("itemId")); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "test item not found")
			return
		}
		s.serverError(w, "remove test item", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
