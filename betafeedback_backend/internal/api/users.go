package api

import (
	"errors"
	"net/http"

	"github.com/adetoba/betafeedback_backend/internal/model"
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
	PushNotifications  *bool `json:"push_notifications"`
}

func (s *Server) updatePreferences(w http.ResponseWriter, r *http.Request, userID string) {
	var req updatePreferencesRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.EmailNotifications == nil && req.PushNotifications == nil {
		writeError(w, http.StatusBadRequest, "no preferences provided")
		return
	}

	var user model.User
	var err error

	if req.EmailNotifications != nil {
		user, err = s.store.SetEmailNotifications(r.Context(), userID, *req.EmailNotifications)
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				writeError(w, http.StatusNotFound, "user not found")
				return
			}
			s.serverError(w, "update email preferences", err)
			return
		}
	}

	if req.PushNotifications != nil {
		user, err = s.store.SetPushNotifications(r.Context(), userID, *req.PushNotifications)
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				writeError(w, http.StatusNotFound, "user not found")
				return
			}
			s.serverError(w, "update push preferences", err)
			return
		}
	}

	writeJSON(w, http.StatusOK, user)
}
