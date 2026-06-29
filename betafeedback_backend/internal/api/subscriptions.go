package api

import "net/http"

func (s *Server) getSubscription(w http.ResponseWriter, r *http.Request, userID string) {
	sub, err := s.store.GetSubscription(r.Context(), userID)
	if err != nil {
		s.serverError(w, "get subscription", err)
		return
	}
	writeJSON(w, http.StatusOK, sub)
}

type updateSubscriptionRequest struct {
	Plan string `json:"plan"`
}

func (s *Server) updateSubscription(w http.ResponseWriter, r *http.Request, userID string) {
	var req updateSubscriptionRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	switch req.Plan {
	case "free", "pro":
	default:
		writeError(w, http.StatusBadRequest, "plan must be free or pro")
		return
	}

	sub, err := s.store.SetPlan(r.Context(), userID, req.Plan)
	if err != nil {
		s.serverError(w, "set plan", err)
		return
	}
	writeJSON(w, http.StatusOK, sub)
}
