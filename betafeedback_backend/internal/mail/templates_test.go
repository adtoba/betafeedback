package mail

import (
	"strings"
	"testing"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func TestOTPHTMLIncludesCode(t *testing.T) {
	html := OTP("123456").HTML()
	for _, want := range []string{
		"BetaFeedback",
		"123456",
		"Your sign-in code",
		"color-scheme",
		"prefers-color-scheme: dark",
	} {
		if !strings.Contains(html, want) {
			t.Fatalf("OTP HTML missing %q", want)
		}
	}
}

func TestNewFeedbackEscapesHTML(t *testing.T) {
	msg := NewFeedback("App <x>", "Ada", "Title & more", "Body <script>", "https://betafeedback.com/open/projects/1")
	html := msg.HTML()
	if strings.Contains(html, "<script>") {
		t.Fatal("unescaped script in HTML")
	}
	if !strings.Contains(html, "Title &amp; more") {
		t.Fatal("expected escaped ampersand")
	}
	if !strings.Contains(html, "Open project") {
		t.Fatal("missing CTA")
	}
	text := msg.Text()
	if !strings.Contains(text, "https://betafeedback.com/open/projects/1") {
		t.Fatal("missing CTA URL in text")
	}
}

func TestTesterWelcomeIncludesLinks(t *testing.T) {
	project := model.Project{
		Name: "ShopFlow",
		PlatformLinks: []model.PlatformLink{
			{Platform: "ios", URL: "https://testflight.apple.com/join/abc"},
			{Platform: "android", URL: "https://play.google.com/apps/testing/com.example"},
		},
	}
	sections := ProjectBuildLinkSections(project)
	if len(sections) != 2 {
		t.Fatalf("expected 2 link sections, got %d", len(sections))
	}

	msg := TesterWelcome(project.Name, "https://betafeedback.com/open/projects/1", sections, "")
	text := msg.Text()
	for _, want := range []string{
		"Welcome to ShopFlow",
		"https://testflight.apple.com/join/abc",
		"https://play.google.com/apps/testing/com.example",
		"Open project in BetaFeedback",
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("TesterWelcome text missing %q", want)
		}
	}
}

func TestTesterWelcomeWithoutLinks(t *testing.T) {
	msg := TesterWelcome("ShopFlow", "https://betafeedback.com/open/projects/1", nil, "")
	if !strings.Contains(msg.Intro, "ask the project creator") {
		t.Fatal("expected fallback copy when no links configured")
	}
}
