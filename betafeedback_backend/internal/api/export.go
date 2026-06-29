package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/store"
)

func (s *Server) exportProject(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	role, ok := s.requireMember(w, r, id, userID)
	if !ok {
		return
	}
	if role != "developer" && role != "creator" {
		writeError(w, http.StatusForbidden, "only developers or the creator can export data")
		return
	}

	pro, err := s.store.UserIsPro(r.Context(), userID)
	if err != nil {
		s.serverError(w, "check subscription", err)
		return
	}
	if !pro {
		writeError(w, http.StatusPaymentRequired, "export is available on the Pro plan")
		return
	}

	kind := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("type")))
	if kind == "" {
		kind = "bugs"
	}

	var csv string
	switch kind {
	case "bugs":
		csv, err = s.store.ExportBugsCSV(r.Context(), id)
	case "feedback":
		csv, err = s.store.ExportFeedbackCSV(r.Context(), id)
	default:
		writeError(w, http.StatusBadRequest, "type must be bugs or feedback")
		return
	}
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "project not found")
			return
		}
		s.serverError(w, "export", err)
		return
	}

	filename := kind + ".csv"
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(csv))
}
