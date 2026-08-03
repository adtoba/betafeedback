package config

import "testing"

func TestGoogleAudiences(t *testing.T) {
	cfg := Config{
		GoogleClientID:    " web.apps.googleusercontent.com , web.apps.googleusercontent.com ",
		GoogleIOSClientID: "ios.apps.googleusercontent.com",
	}
	audiences := cfg.GoogleAudiences()
	if len(audiences) != 2 {
		t.Fatalf("expected 2 audiences, got %d: %v", len(audiences), audiences)
	}
	if audiences[0] != "web.apps.googleusercontent.com" {
		t.Fatalf("unexpected web audience: %q", audiences[0])
	}
	if audiences[1] != "ios.apps.googleusercontent.com" {
		t.Fatalf("unexpected ios audience: %q", audiences[1])
	}
	if got := cfg.GoogleWebClientID(); got != "web.apps.googleusercontent.com" {
		t.Fatalf("unexpected web client id: %q", got)
	}
}
