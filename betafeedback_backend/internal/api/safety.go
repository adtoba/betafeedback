package api

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/mail"
	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request, userID string) {
	projectIDs, err := s.store.DeleteUser(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		s.serverError(w, "delete account", err)
		return
	}
	for _, id := range projectIDs {
		_ = os.RemoveAll(filepath.Join(s.cfg.MediaDir, id))
	}
	writeJSON(w, http.StatusNoContent, nil)
}

type reportUserRequest struct {
	Reason  string `json:"reason"`
	Details string `json:"details"`
}

func (s *Server) reportUser(w http.ResponseWriter, r *http.Request, userID string) {
	reportedID := strings.TrimSpace(r.PathValue("id"))
	if reportedID == "" {
		writeError(w, http.StatusBadRequest, "user id is required")
		return
	}

	var req reportUserRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	rep, err := s.store.CreateUserReport(r.Context(), userID, reportedID, req.Reason, req.Details)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusBadRequest, conflictMessage(err))
			return
		}
		s.serverError(w, "report user", err)
		return
	}

	s.emailUserReport(r.Context(), rep)
	writeJSON(w, http.StatusCreated, rep)
}

func (s *Server) blockUser(w http.ResponseWriter, r *http.Request, userID string) {
	blockedID := strings.TrimSpace(r.PathValue("id"))
	if blockedID == "" {
		writeError(w, http.StatusBadRequest, "user id is required")
		return
	}
	if err := s.store.BlockUser(r.Context(), userID, blockedID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusBadRequest, conflictMessage(err))
			return
		}
		s.serverError(w, "block user", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"blocked": true})
}

func (s *Server) unblockUser(w http.ResponseWriter, r *http.Request, userID string) {
	blockedID := strings.TrimSpace(r.PathValue("id"))
	if blockedID == "" {
		writeError(w, http.StatusBadRequest, "user id is required")
		return
	}
	if err := s.store.UnblockUser(r.Context(), userID, blockedID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "block not found")
			return
		}
		s.serverError(w, "unblock user", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"blocked": false})
}

func (s *Server) adminListReports(w http.ResponseWriter, r *http.Request, _ string) {
	limit, offset := adminPageParams(r)
	items, total, err := s.store.AdminListReports(r.Context(), limit, offset)
	if err != nil {
		s.serverError(w, "admin list reports", err)
		return
	}
	writeAdminList(w, items, total, limit, offset)
}

func (s *Server) emailUserReport(ctx context.Context, rep model.UserReport) {
	msg := mail.ContentReport(rep.ReporterEmail, rep.ReportedEmail, rep.Reason, rep.Details)
	seen := map[string]bool{}
	for _, to := range s.cfg.AdminEmails {
		to = strings.TrimSpace(to)
		if to == "" || seen[to] {
			continue
		}
		seen[to] = true
		msg.To = to
		if err := s.mailer.SendMessage(ctx, msg); err != nil {
			s.logger.Error("send report email", "err", err, "to", to)
		}
	}
}
