package api

import (
	"net/http"
	"strings"
)

type registerDeviceRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

func (s *Server) registerDevice(w http.ResponseWriter, r *http.Request, userID string) {
	var req registerDeviceRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	token := strings.TrimSpace(req.Token)
	platform := strings.ToLower(strings.TrimSpace(req.Platform))
	if token == "" {
		writeError(w, http.StatusBadRequest, "token is required")
		return
	}
	if platform != "ios" && platform != "android" {
		writeError(w, http.StatusBadRequest, "platform must be ios or android")
		return
	}
	if err := s.store.UpsertDeviceToken(r.Context(), userID, token, platform); err != nil {
		s.serverError(w, "register device", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type unregisterDeviceRequest struct {
	Token string `json:"token"`
}

func (s *Server) unregisterDevice(w http.ResponseWriter, r *http.Request, userID string) {
	var req unregisterDeviceRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	token := strings.TrimSpace(req.Token)
	if token == "" {
		writeError(w, http.StatusBadRequest, "token is required")
		return
	}
	if err := s.store.DeleteDeviceToken(r.Context(), userID, token); err != nil {
		s.serverError(w, "unregister device", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
