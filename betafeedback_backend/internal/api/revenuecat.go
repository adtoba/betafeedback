package api

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"
)

// RevenueCat webhook envelope: https://www.revenuecat.com/docs/integrations/webhooks
type rcWebhookPayload struct {
	APIVersion string   `json:"api_version"`
	Event      rcEvent  `json:"event"`
}

type rcEvent struct {
	ID               string   `json:"id"`
	Type             string   `json:"type"`
	AppUserID        string   `json:"app_user_id"`
	OriginalAppUserID string  `json:"original_app_user_id"`
	Aliases          []string `json:"aliases"`
	EntitlementID    *string  `json:"entitlement_id"`
	EntitlementIDs   []string `json:"entitlement_ids"`
	ProductID        string   `json:"product_id"`
	PeriodType       string   `json:"period_type"`
	ExpirationAtMs   *int64   `json:"expiration_at_ms"`
	Environment      string   `json:"environment"`
}

func (s *Server) revenueCatWebhook(w http.ResponseWriter, r *http.Request) {
	if !s.verifyRevenueCatAuth(r) {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	var payload rcWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}

	ev := payload.Event
	if ev.Type == "" || ev.Type == "TEST" {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		return
	}

	// Ignore events that don't affect Pro access.
	switch ev.Type {
	case "INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE",
		"SUBSCRIPTION_EXTENDED", "NON_RENEWING_PURCHASE",
		"TEMPORARY_ENTITLEMENT_GRANT", "REFUND_REVERSED",
		"EXPIRATION", "BILLING_ISSUE", "CANCELLATION":
	default:
		writeJSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}

	userID := s.resolveRCUserID(r, ev)
	if userID == "" {
		s.logger.Warn("revenuecat webhook: unknown user",
			"app_user_id", ev.AppUserID, "type", ev.Type, "event_id", ev.ID)
		// Ack so RevenueCat doesn't retry forever for anonymous/$RCAnonymousID noise.
		writeJSON(w, http.StatusOK, map[string]string{"status": "unknown_user"})
		return
	}

	plan, status, renews := mapRCEvent(ev, s.cfg.RevenueCatEntitlementID)
	if _, err := s.store.SetSubscriptionFromBilling(r.Context(), userID, plan, status, renews, ev.ID, ev.ProductID); err != nil {
		s.serverError(w, "revenuecat apply", err)
		return
	}

	s.logger.Info("revenuecat webhook applied",
		"user_id", userID, "type", ev.Type, "plan", plan, "status", status, "event_id", ev.ID)
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) verifyRevenueCatAuth(r *http.Request) bool {
	expected := strings.TrimSpace(s.cfg.RevenueCatWebhookAuth)
	if expected == "" {
		// Allow unauthenticated webhooks only in local development.
		return s.cfg.IsDevelopment()
	}
	got := strings.TrimSpace(r.Header.Get("Authorization"))
	if got == expected {
		return true
	}
	// Dashboard value may be stored with or without a Bearer prefix.
	strip := func(v string) string {
		return strings.TrimSpace(strings.TrimPrefix(v, "Bearer "))
	}
	return strip(got) != "" && strip(got) == strip(expected)
}

func (s *Server) resolveRCUserID(r *http.Request, ev rcEvent) string {
	candidates := make([]string, 0, 2+len(ev.Aliases))
	for _, id := range []string{ev.AppUserID, ev.OriginalAppUserID} {
		id = strings.TrimSpace(id)
		if id == "" || strings.HasPrefix(id, "$RCAnonymousID:") {
			continue
		}
		candidates = append(candidates, id)
	}
	for _, id := range ev.Aliases {
		id = strings.TrimSpace(id)
		if id == "" || strings.HasPrefix(id, "$RCAnonymousID:") {
			continue
		}
		candidates = append(candidates, id)
	}
	for _, id := range candidates {
		if ok, err := s.store.UserExists(r.Context(), id); err == nil && ok {
			return id
		}
	}
	return ""
}

// mapRCEvent derives our plan/status/renewal date from a RevenueCat event.
func mapRCEvent(ev rcEvent, entitlementID string) (plan, status string, renews *time.Time) {
	hasPro := rcHasEntitlement(ev, entitlementID)
	var renewsOn *time.Time
	if ev.ExpirationAtMs != nil && *ev.ExpirationAtMs > 0 {
		t := time.UnixMilli(*ev.ExpirationAtMs).UTC()
		renewsOn = &t
	}

	switch ev.Type {
	case "EXPIRATION":
		return "free", "active", nil
	case "BILLING_ISSUE":
		if hasPro {
			return "pro", "past_due", renewsOn
		}
		return "free", "active", nil
	case "CANCELLATION":
		// Access continues until EXPIRATION.
		if hasPro {
			return "pro", "active", renewsOn
		}
		return "free", "active", nil
	default:
		if !hasPro {
			return "free", "active", nil
		}
		st := "active"
		if strings.EqualFold(ev.PeriodType, "TRIAL") {
			st = "trialing"
		}
		return "pro", st, renewsOn
	}
}

func rcHasEntitlement(ev rcEvent, entitlementID string) bool {
	want := strings.TrimSpace(entitlementID)
	if want == "" {
		want = "pro"
	}
	if ev.EntitlementID != nil && *ev.EntitlementID == want {
		return true
	}
	for _, id := range ev.EntitlementIDs {
		if id == want {
			return true
		}
	}
	// Fallback: product id contains "pro" (covers misconfigured entitlement_ids on some events).
	return strings.Contains(strings.ToLower(ev.ProductID), "pro")
}
