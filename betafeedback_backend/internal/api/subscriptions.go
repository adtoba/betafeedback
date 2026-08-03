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

// updateSubscription is a development-only stub. Production plan changes come
// from the RevenueCat webhook after a real App Store / Play purchase.
func (s *Server) updateSubscription(w http.ResponseWriter, r *http.Request, userID string) {
	if !s.cfg.IsDevelopment() {
		writeError(w, http.StatusForbidden, "subscription changes are handled by the App Store / Play Store")
		return
	}

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
