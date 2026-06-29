package api

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) listFeedback(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	items, err := s.store.ListFeedback(r.Context(), id)
	if err != nil {
		s.serverError(w, "list feedback", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"feedback": items})
}

type createFeedbackRequest struct {
	Title       string `json:"title"`
	Body        string `json:"body"`
	Device      string `json:"device"`
	AppVersion  string `json:"app_version"`
	Platform    string `json:"platform"`
	Screenshots []struct {
		Label       string `json:"label"`
		Hue         int    `json:"hue"`
		URL         string `json:"url"`
		ContentType string `json:"content_type"`
	} `json:"screenshots"`
}

func (s *Server) createFeedback(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "tester" && role != "creator" && role != "developer" {
		writeError(w, http.StatusForbidden, "only testers, developers, or the creator can submit feedback")
		return
	}

	var req createFeedbackRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if strings.TrimSpace(req.Body) == "" {
		writeError(w, http.StatusBadRequest, "body is required")
		return
	}

	shots := make([]model.Screenshot, 0, len(req.Screenshots))
	for _, sc := range req.Screenshots {
		label := strings.TrimSpace(sc.Label)
		url := strings.TrimSpace(sc.URL)
		if label == "" && url == "" {
			continue
		}
		if label == "" {
			label = "Attachment"
		}
		shots = append(shots, model.Screenshot{
			Label:       label,
			Hue:         sc.Hue,
			URL:         url,
			ContentType: strings.TrimSpace(sc.ContentType),
		})
	}

	feedback, err := s.store.CreateFeedback(r.Context(), model.Feedback{
		ProjectID:   id,
		AuthorID:    userID,
		Title:       optionalString(req.Title),
		Body:        strings.TrimSpace(req.Body),
		Device:      optionalString(req.Device),
		AppVersion:  optionalString(req.AppVersion),
		Platform:    optionalString(req.Platform),
		Screenshots: shots,
	})
	if err != nil {
		s.serverError(w, "create feedback", err)
		return
	}

	// Draft a structured bug in the background; never block submission on it.
	go s.autoStructureFeedback(feedback)
	go s.emailNewFeedback(context.Background(), feedback.ProjectID, feedback)

	writeJSON(w, http.StatusCreated, feedback)
}

type createCommentRequest struct {
	Body string `json:"body"`
}

func (s *Server) createFeedbackComment(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	feedbackID := r.PathValue("feedbackId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can reply to feedback")
		return
	}

	var req createCommentRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	body := strings.TrimSpace(req.Body)
	if body == "" {
		writeError(w, http.StatusBadRequest, "body is required")
		return
	}

	comment, err := s.store.CreateFeedbackComment(r.Context(), id, feedbackID, userID, body)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "feedback not found")
			return
		}
		s.serverError(w, "create comment", err)
		return
	}
	writeJSON(w, http.StatusCreated, comment)
}

// autoStructureFeedback runs after a tester submits feedback: if the text looks
// like a defect, it drafts a structured bug in the 'suggested' state for a
// developer to confirm. It runs in its own goroutine so submission never blocks
// on — or fails because of — the structuring step.
func (s *Server) autoStructureFeedback(fb model.Feedback) {
	title := ""
	if fb.Title != nil {
		title = *fb.Title
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	analysis := s.structurer.Analyze(ctx, title, fb.Body)
	if !analysis.IsBug {
		return
	}

	already, err := s.store.BugForFeedback(ctx, fb.ID)
	if err != nil {
		s.logger.Error("auto-structure: check existing bug", "err", err)
		return
	}
	if already {
		return
	}

	if _, err := s.store.SuggestBug(ctx, fb.ProjectID, fb.ID, model.StructuredBug{
		Title:    analysis.Title,
		Steps:    analysis.Steps,
		Expected: analysis.Expected,
		Actual:   analysis.Actual,
		Severity: analysis.Severity,
	}); err != nil {
		s.logger.Error("auto-structure: suggest bug", "err", err)
		return
	}
	s.emailSuggestedBug(ctx, fb.ProjectID, analysis.Title)
}
