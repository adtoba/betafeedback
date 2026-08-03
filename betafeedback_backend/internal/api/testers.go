package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func conflictMessage(err error) string {
	msg := err.Error()
	msg = strings.TrimPrefix(msg, "conflict: ")
	if msg == "" || msg == "conflict" {
		return "conflict"
	}
	return msg
}

type updateTesterProfileRequest struct {
	OpenToTest *bool   `json:"open_to_test"`
	TesterBio  *string `json:"tester_bio"`
}

func (s *Server) updateTesterProfile(w http.ResponseWriter, r *http.Request, userID string) {
	var req updateTesterProfileRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.OpenToTest == nil && req.TesterBio == nil {
		writeError(w, http.StatusBadRequest, "no tester profile fields provided")
		return
	}

	user, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "get user", err)
		return
	}

	open := user.OpenToTest
	bio := user.TesterBio
	if req.OpenToTest != nil {
		open = *req.OpenToTest
	}
	if req.TesterBio != nil {
		bio = strings.TrimSpace(*req.TesterBio)
		if len(bio) > 280 {
			writeError(w, http.StatusBadRequest, "bio must be 280 characters or fewer")
			return
		}
	}

	user, err = s.store.UpdateTesterProfile(r.Context(), userID, open, bio)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "update tester profile", err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (s *Server) listTesters(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := strings.TrimSpace(r.URL.Query().Get("project_id"))
	query := strings.TrimSpace(r.URL.Query().Get("q"))

	if projectID != "" {
		role, ok := s.requireMember(w, r, projectID, userID)
		if !ok {
			return
		}
		if role != "creator" {
			writeError(w, http.StatusForbidden, "only the creator can browse testers for a project")
			return
		}
	}

	testers, err := s.store.ListOpenTesters(r.Context(), userID, projectID, query, 40)
	if err != nil {
		s.serverError(w, "list testers", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"testers": testers})
}

func (s *Server) listTopTesters(w http.ResponseWriter, r *http.Request, userID string) {
	testers, err := s.store.ListTopTesters(r.Context(), userID, 20)
	if err != nil {
		s.serverError(w, "list top testers", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"testers": testers})
}

type createTesterInviteRequest struct {
	UserID  string `json:"user_id"`
	Message string `json:"message"`
}

func (s *Server) createTesterInvite(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := r.PathValue("id")
	role, ok := s.requireMember(w, r, projectID, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can invite testers")
		return
	}

	var req createTesterInviteRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	toUserID := strings.TrimSpace(req.UserID)
	if toUserID == "" {
		writeError(w, http.StatusBadRequest, "user_id is required")
		return
	}
	message := strings.TrimSpace(req.Message)
	if len(message) > 500 {
		writeError(w, http.StatusBadRequest, "message must be 500 characters or fewer")
		return
	}

	inv, err := s.store.CreateTesterInvitation(r.Context(), projectID, userID, toUserID, message)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "tester not found")
			return
		}
        if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, "create tester invite", err)
		return
	}

	s.pushToUsers(r.Context(), []string{toUserID}, projectID, "tester_invite",
		"Tester invitation", inv.ProjectName+" wants you to test their app")

	writeJSON(w, http.StatusCreated, inv)
}

func (s *Server) listProjectTesterInvites(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := r.PathValue("id")
	role, ok := s.requireMember(w, r, projectID, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can view project invitations")
		return
	}

	invites, err := s.store.ListProjectTesterInvitations(r.Context(), projectID)
	if err != nil {
		s.serverError(w, "list project tester invites", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"invitations": invites})
}

func (s *Server) listMyTesterInvites(w http.ResponseWriter, r *http.Request, userID string) {
	invites, err := s.store.ListIncomingTesterInvitations(r.Context(), userID)
	if err != nil {
		s.serverError(w, "list my tester invites", err)
		return
	}
	pending, _ := s.store.CountPendingTesterInvitations(r.Context(), userID)
	writeJSON(w, http.StatusOK, map[string]any{
		"invitations": invites,
		"pending":     pending,
	})
}

func (s *Server) acceptTesterInvite(w http.ResponseWriter, r *http.Request, userID string) {
	s.respondTesterInvite(w, r, userID, "accepted")
}

func (s *Server) declineTesterInvite(w http.ResponseWriter, r *http.Request, userID string) {
	s.respondTesterInvite(w, r, userID, "declined")
}

func (s *Server) respondTesterInvite(w http.ResponseWriter, r *http.Request, userID, status string) {
	inviteID := r.PathValue("inviteId")
	inv, err := s.store.RespondTesterInvitation(r.Context(), inviteID, userID, status)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "invitation not found")
			return
		}
		if errors.Is(err, store.ErrForbidden) {
			writeError(w, http.StatusForbidden, "not your invitation")
			return
		}
        if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, "respond tester invite", err)
		return
	}

	if status == "accepted" {
		s.pushToUsers(r.Context(), []string{inv.FromUserID}, inv.ProjectID, "tester_joined",
			"Tester joined", inv.ToUserName+" accepted your invitation to test "+inv.ProjectName)
	}

	writeJSON(w, http.StatusOK, inv)
}

type rateTesterRequest struct {
	Score   int    `json:"score"`
	Comment string `json:"comment"`
}

func (s *Server) rateTester(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := r.PathValue("id")
	testerID := r.PathValue("userId")
	role, ok := s.requireMember(w, r, projectID, userID)
	if !ok {
		return
	}
	if role != "creator" {
		writeError(w, http.StatusForbidden, "only the creator can rate testers")
		return
	}

	var req rateTesterRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Score < 1 || req.Score > 5 {
		writeError(w, http.StatusBadRequest, "score must be between 1 and 5")
		return
	}
	comment := strings.TrimSpace(req.Comment)
	if len(comment) > 500 {
		writeError(w, http.StatusBadRequest, "comment must be 500 characters or fewer")
		return
	}

	rating, err := s.store.RateTester(r.Context(), projectID, userID, testerID, req.Score, comment)
	if err != nil {
        if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, "rate tester", err)
		return
	}
	writeJSON(w, http.StatusOK, rating)
}

func (s *Server) listMyTesterRatings(w http.ResponseWriter, r *http.Request, userID string) {
	ratings, err := s.store.ListTesterRatingsForUser(r.Context(), userID)
	if err != nil {
		s.serverError(w, "list tester ratings", err)
		return
	}
	if ratings == nil {
		ratings = []model.TesterRating{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ratings": ratings})
}
