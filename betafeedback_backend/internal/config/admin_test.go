package config

import "testing"

func TestIsAdminEmail(t *testing.T) {
	cfg := Config{AdminEmails: parseEmailList("Ops@Example.com, other@test.com")}
	if !cfg.IsAdminEmail("ops@example.com") {
		t.Fatal("expected case-insensitive match")
	}
	if cfg.IsAdminEmail("nobody@example.com") {
		t.Fatal("unexpected match")
	}
	if (Config{}).IsAdminEmail("ops@example.com") {
		t.Fatal("empty allowlist should deny")
	}
}
