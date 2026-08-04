package api

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) listSwapPartners(w http.ResponseWriter, r *http.Request, userID string) {
	projectID := strings.TrimSpace(r.URL.Query().Get("project_id"))
	query := strings.TrimSpace(r.URL.Query().Get("q"))

	if projectID != "" {
		role, ok := s.requireMember(w, r, projectID, userID)
		if !ok {
			return
		}
		if role != "creator" {
			writeError(w, http.StatusForbidden, "only the creator can browse swap partners")
			return
		}
	}

	partners, err := s.store.ListSwapPartners(r.Context(), userID, projectID, query, 40)
	if err != nil {
		s.serverError(w, "list swap partners", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"partners": partners})
}

type createSwapRequest struct {
	FromProjectID string `json:"from_project_id"`
	ToProjectID   string `json:"to_project_id"`
	Message       string `json:"message"`
}

func (s *Server) createSwap(w http.ResponseWriter, r *http.Request, userID string) {
	if !s.requireProForSwaps(w, r, userID) {
		return
	}

	var req createSwapRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	fromProjectID := strings.TrimSpace(req.FromProjectID)
	toProjectID := strings.TrimSpace(req.ToProjectID)
	if fromProjectID == "" || toProjectID == "" {
		writeError(w, http.StatusBadRequest, "from_project_id and to_project_id are required")
		return
	}
	message := strings.TrimSpace(req.Message)
	if len(message) > 500 {
		writeError(w, http.StatusBadRequest, "message must be 500 characters or fewer")
		return
	}

	sw, err := s.store.CreateTestSwap(r.Context(), userID, fromProjectID, toProjectID, message)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "project not found")
			return
		}
		if errors.Is(err, store.ErrForbidden) {
			writeError(w, http.StatusForbidden, "only the creator can propose a swap for their project")
			return
		}
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, "create swap", err)
		return
	}

	go s.pushToUsers(
		context.Background(),
		[]string{sw.ToUserID},
		sw.FromProjectID,
		"swap_invite",
		"Test-for-test proposal",
		fmt.Sprintf("%s wants to swap: you test %s, they test %s",
			sw.FromUserName, sw.FromProjectName, sw.ToProjectName),
	)

	writeJSON(w, http.StatusCreated, sw)
}

func (s *Server) listMySwaps(w http.ResponseWriter, r *http.Request, userID string) {
	swaps, err := s.store.ListMyTestSwaps(r.Context(), userID)
	if err != nil {
		s.serverError(w, "list swaps", err)
		return
	}
	pending, err := s.store.CountPendingIncomingSwaps(r.Context(), userID)
	if err != nil {
		s.serverError(w, "count pending swaps", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"swaps":   swaps,
		"pending": pending,
	})
}

func (s *Server) acceptSwap(w http.ResponseWriter, r *http.Request, userID string) {
	s.respondSwap(w, r, userID, "accept")
}

func (s *Server) declineSwap(w http.ResponseWriter, r *http.Request, userID string) {
	s.respondSwap(w, r, userID, "decline")
}

func (s *Server) cancelSwap(w http.ResponseWriter, r *http.Request, userID string) {
	s.respondSwap(w, r, userID, "cancel")
}

func (s *Server) requireProForSwaps(w http.ResponseWriter, r *http.Request, userID string) bool {
	pro, err := s.store.UserIsPro(r.Context(), userID)
	if err != nil {
		s.serverError(w, "check subscription", err)
		return false
	}
	if !pro {
		writeError(w, http.StatusPaymentRequired,
			"test-for-test swaps are available on the Pro plan")
		return false
	}
	return true
}

func (s *Server) respondSwap(w http.ResponseWriter, r *http.Request, userID, action string) {
	if action == "accept" && !s.requireProForSwaps(w, r, userID) {
		return
	}

	swapID := r.PathValue("swapId")
	var (
		sw  model.TestSwap
		err error
	)
	switch action {
	case "accept":
		sw, err = s.store.AcceptTestSwap(r.Context(), swapID, userID)
	case "decline":
		sw, err = s.store.DeclineTestSwap(r.Context(), swapID, userID)
	case "cancel":
		sw, err = s.store.CancelTestSwap(r.Context(), swapID, userID)
	default:
		writeError(w, http.StatusBadRequest, "unknown action")
		return
	}
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "swap not found")
			return
		}
		if errors.Is(err, store.ErrForbidden) {
			writeError(w, http.StatusForbidden, "not allowed")
			return
		}
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, conflictMessage(err))
			return
		}
		s.serverError(w, action+" swap", err)
		return
	}

	if action == "accept" {
		go s.pushToUsers(
			context.Background(),
			[]string{sw.FromUserID},
			sw.ToProjectID,
			"swap_accepted",
			"Swap accepted",
			fmt.Sprintf("You're now testers on %s and %s", sw.FromProjectName, sw.ToProjectName),
		)
	}

	writeJSON(w, http.StatusOK, sw)
}

func (s *Server) maybeFulfillSwaps(ctx context.Context, projectID, authorID string) {
	fulfilled, err := s.store.MaybeFulfillSwapsForFeedback(ctx, projectID, authorID)
	if err != nil {
		s.logger.Error("fulfill swaps", "err", err)
		return
	}
	for _, sw := range fulfilled {
		title := "Swap complete"
		body := fmt.Sprintf("Both of you filed feedback on %s and %s", sw.FromProjectName, sw.ToProjectName)
		s.pushToUsers(ctx, []string{sw.FromUserID, sw.ToUserID}, sw.FromProjectID, "swap_fulfilled", title, body)
	}
}
