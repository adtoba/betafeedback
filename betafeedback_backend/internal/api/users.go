package api

import (
	"errors"
	"net/http"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) getMe(w http.ResponseWriter, r *http.Request, userID string) {
	user, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "get user", err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

type updatePreferencesRequest struct {
	EmailNotifications *bool `json:"email_notifications"`
}

func (s *Server) updatePreferences(w http.ResponseWriter, r *http.Request, userID string) {
	var req updatePreferencesRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.EmailNotifications == nil {
		writeError(w, http.StatusBadRequest, "email_notifications is required")
		return
	}

	if *req.EmailNotifications {
		pro, err := s.store.UserIsPro(r.Context(), userID)
		if err != nil {
			s.serverError(w, "check subscription", err)
			return
		}
		if !pro {
			writeError(w, http.StatusPaymentRequired,
				"email notifications are available on the Pro plan")
			return
		}
	}

	user, err := s.store.SetEmailNotifications(r.Context(), userID, *req.EmailNotifications)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "update preferences", err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}
