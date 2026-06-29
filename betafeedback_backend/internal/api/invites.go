package api

import (
	"errors"
	"net/http"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

// getInvite returns the public summary for an invite code. It is unauthenticated
// so the betafeedback_web /join page can render before a tester has signed in.
func (s *Server) getInvite(w http.ResponseWriter, r *http.Request) {
	code := r.PathValue("code")
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
