package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

// getInvite returns the public summary for an invite code. It is unauthenticated
// so the betafeedback_web /join page can render before a tester has signed in.
func (s *Server) getInvite(w http.ResponseWriter, r *http.Request) {
	code := strings.TrimSpace(strings.TrimSuffix(r.PathValue("code"), "/"))
	info, err := s.store.InviteInfo(r.Context(), code)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "invite not found")
			return
		}
		s.serverError(w, "invite info", err)
		return
	}
	writeJSON(w, http.StatusOK, info)
}

// joinInvite adds the authenticated user to the project for an invite code.
func (s *Server) joinInvite(w http.ResponseWriter, r *http.Request, userID string) {
	code := strings.TrimSpace(strings.TrimSuffix(r.PathValue("code"), "/"))
	if code == "" {
		writeError(w, http.StatusBadRequest, "invite code is required")
		return
	}
	project, newlyJoined, err := s.store.JoinByInviteCode(r.Context(), code, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "invite not found")
			return
		}
		s.serverError(w, "join invite", err)
		return
	}
	if newlyJoined {
		tester, err := s.store.GetUser(r.Context(), userID)
		if err == nil {
			s.onTesterJoined(r.Context(), project, tester)
		}
	}
	writeJSON(w, http.StatusOK, project)
}
