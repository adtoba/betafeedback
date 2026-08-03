package api

import (
	"testing"
	"time"
)

func TestMapRCEventGrantAndExpire(t *testing.T) {
	ent := "pro"
	exp := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC).UnixMilli()

	plan, status, renews := mapRCEvent(rcEvent{
		Type:           "INITIAL_PURCHASE",
		EntitlementIDs: []string{"pro"},
		PeriodType:     "NORMAL",
		ExpirationAtMs: &exp,
	}, ent)
	if plan != "pro" || status != "active" || renews == nil {
		t.Fatalf("grant: got plan=%s status=%s renews=%v", plan, status, renews)
	}

	plan, status, renews = mapRCEvent(rcEvent{
		Type:           "INITIAL_PURCHASE",
		EntitlementIDs: []string{"pro"},
		PeriodType:     "TRIAL",
		ExpirationAtMs: &exp,
	}, ent)
	if plan != "pro" || status != "trialing" {
		t.Fatalf("trial: got plan=%s status=%s", plan, status)
	}

	plan, status, renews = mapRCEvent(rcEvent{Type: "EXPIRATION", EntitlementIDs: []string{"pro"}}, ent)
	if plan != "free" || status != "active" || renews != nil {
		t.Fatalf("expire: got plan=%s status=%s renews=%v", plan, status, renews)
	}

	plan, status, _ = mapRCEvent(rcEvent{
		Type:           "BILLING_ISSUE",
		EntitlementIDs: []string{"pro"},
		ExpirationAtMs: &exp,
	}, ent)
	if plan != "pro" || status != "past_due" {
		t.Fatalf("billing: got plan=%s status=%s", plan, status)
	}
}
