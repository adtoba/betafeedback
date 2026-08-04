package mail

import (
	"strings"
	"testing"
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
	msg := NewFeedback("App <x>", "Ada", "Title & more", "Body <script>", "https://betafeedback.com/app/projects/1")
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
	if !strings.Contains(text, "https://betafeedback.com/app/projects/1") {
		t.Fatal("missing CTA URL in text")
	}
}
