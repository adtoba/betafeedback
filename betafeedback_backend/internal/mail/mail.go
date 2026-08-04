package mail

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/resend/resend-go/v3"
)

// Config configures outbound email via Resend. When [Enabled] is false, sends
// are logged instead of delivered (handy for local development).
type Config struct {
	APIKey string
	From   string
}

type Sender struct {
	cfg    Config
	client *resend.Client
	logger *slog.Logger
}

func NewSender(cfg Config, logger *slog.Logger) *Sender {
	s := &Sender{cfg: cfg, logger: logger}
	if cfg.Enabled() {
		s.client = resend.NewClient(strings.TrimSpace(cfg.APIKey))
	}
	return s
}

func (c Config) Enabled() bool {
	return strings.TrimSpace(c.APIKey) != "" && strings.TrimSpace(c.From) != ""
}

// Send delivers a plain-text email (with a matching HTML body). No-op (with a
// log line) when Resend is unset.
func (s *Sender) Send(ctx context.Context, to, subject, body string) error {
	to = strings.TrimSpace(to)
	if to == "" {
		return nil
	}
	if !s.cfg.Enabled() || s.client == nil {
		s.logger.Info("email (resend not configured)",
			"to", to, "subject", subject, "body", body)
		return nil
	}

	params := &resend.SendEmailRequest{
		From:    s.cfg.From,
		To:      []string{to},
		Subject: subject,
		Text:    body,
		Html:    textToHTML(body),
	}
	_, err := s.client.Emails.SendWithContext(ctx, params)
	if err != nil {
		return fmt.Errorf("resend: %w", err)
	}
	return nil
}

// SendOTP emails a sign-in verification code.
func (s *Sender) SendOTP(ctx context.Context, to, code string) error {
	subject := "Your BetaFeedback sign-in code"
	body := fmt.Sprintf(
		"Your BetaFeedback sign-in code is %s.\n\n"+
			"It expires in 10 minutes. If you didn't request this, you can ignore this email.\n",
		code,
	)
	return s.Send(ctx, to, subject, body)
}

func textToHTML(body string) string {
	escaped := strings.ReplaceAll(body, "&", "&amp;")
	escaped = strings.ReplaceAll(escaped, "<", "&lt;")
	escaped = strings.ReplaceAll(escaped, ">", "&gt;")
	escaped = strings.ReplaceAll(escaped, "\n", "<br>\n")
	return "<p style=\"font-family:system-ui,sans-serif;font-size:15px;line-height:1.5;color:#111\">" +
		escaped +
		"</p>"
}
