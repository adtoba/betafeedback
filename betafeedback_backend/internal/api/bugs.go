package api

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/adetoba/betafeedback_backend/internal/model"
	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) listBugs(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	if _, ok := s.requireMember(w, r, id, userID); !ok {
		return
	}
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	var bugs []model.StructuredBug
	var err error
	if status != "" {
		bugs, err = s.store.ListBugs(r.Context(), id, status)
	} else {
		bugs, err = s.store.ListBugs(r.Context(), id)
	}
	if err != nil {
		s.serverError(w, "list bugs", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"bugs": bugs})
}

func (s *Server) structureFeedback(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	feedbackID := r.PathValue("feedbackId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can structure feedback")
		return
	}

	fb, err := s.store.GetFeedback(r.Context(), id, feedbackID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "feedback not found")
			return
		}
		s.serverError(w, "load feedback", err)
		return
	}

	already, err := s.store.BugForFeedback(r.Context(), feedbackID)
	if err != nil {
		s.serverError(w, "check existing bug", err)
		return
	}
	if already {
		writeError(w, http.StatusConflict, "feedback already structured")
		return
	}

	title := ""
	if fb.Title != nil {
		title = *fb.Title
	}
	out := s.structurer.Analyze(r.Context(), title, fb.Body)

	bug, err := s.store.StructureFeedback(r.Context(), id, feedbackID, userID, model.StructuredBug{
		Title:        out.Title,
		Steps:        out.Steps,
		Expected:     out.Expected,
		Actual:       out.Actual,
		Severity:     out.Severity,
		StructuredAt: time.Now(),
	})
	if err != nil {
		s.serverError(w, "structure feedback", err)
		return
	}
	writeJSON(w, http.StatusCreated, bug)
}

type fixBugRequest struct {
	Note      string `json:"note"`
	ReleaseID string `json:"release_id"`
}

func (s *Server) fixBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can fix bugs")
		return
	}

	var req fixBugRequest
	if r.ContentLength > 0 {
		if err := decode(r, &req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
	}

	bug, err := s.store.MarkBugFixed(r.Context(), id, bugID, userID,
		optionalString(req.Note), optionalString(req.ReleaseID))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "bug not found or not open")
			return
		}
		s.serverError(w, "fix bug", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

type updateBugRequest struct {
	Title    string   `json:"title"`
	Steps    []string `json:"steps"`
	Expected string   `json:"expected"`
	Actual   string   `json:"actual"`
	Severity string   `json:"severity"`
}

func (s *Server) updateBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can edit bugs")
		return
	}

	var req updateBugRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		writeError(w, http.StatusBadRequest, "title is required")
		return
	}
	if len(req.Steps) == 0 {
		writeError(w, http.StatusBadRequest, "at least one step is required")
		return
	}

	bug, err := s.store.UpdateBug(r.Context(), id, bugID, title,
		strings.TrimSpace(req.Expected), strings.TrimSpace(req.Actual),
		strings.TrimSpace(req.Severity), req.Steps)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "bug not found or cannot be edited")
			return
		}
		s.serverError(w, "update bug", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

type needsInfoRequest struct {
	Note string `json:"note"`
}

func (s *Server) markBugNeedsInfo(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can update bugs")
		return
	}

	var note *string
	if r.ContentLength > 0 {
		var req needsInfoRequest
		if err := decode(r, &req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		note = optionalString(req.Note)
	}

	bug, err := s.store.MarkBugNeedsInfo(r.Context(), id, bugID, userID, note)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "bug not found or not open")
			return
		}
		s.serverError(w, "mark bug needs info", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

func (s *Server) resumeBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can update bugs")
		return
	}

	bug, err := s.store.ResumeBug(r.Context(), id, bugID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "bug not found or not awaiting info")
			return
		}
		s.serverError(w, "resume bug", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

func (s *Server) reopenBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can reopen bugs")
		return
	}

	bug, err := s.store.ReopenBug(r.Context(), id, bugID, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "bug not found or not fixed")
			return
		}
		s.serverError(w, "reopen bug", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

func (s *Server) confirmBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can confirm bugs")
		return
	}

	bug, err := s.store.ConfirmBug(r.Context(), id, bugID, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "suggested bug not found")
			return
		}
		s.serverError(w, "confirm bug", err)
		return
	}
	writeJSON(w, http.StatusOK, bug)
}

func (s *Server) dismissBug(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	bugID := r.PathValue("bugId")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can dismiss bugs")
		return
	}

	if err := s.store.DismissBug(r.Context(), id, bugID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "suggested bug not found")
			return
		}
		s.serverError(w, "dismiss bug", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
