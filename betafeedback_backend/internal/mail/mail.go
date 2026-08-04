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
	APIKey     string
	From       string
	AppBaseURL string
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

// AppBaseURL returns the configured public web origin (no trailing slash).
func (s *Sender) AppBaseURL() string {
	return strings.TrimRight(strings.TrimSpace(s.cfg.AppBaseURL), "/")
}

// ProjectURL builds a dashboard deep link for a project.
func (s *Sender) ProjectURL(projectID string) string {
	base := s.AppBaseURL()
	if base == "" || projectID == "" {
		return ""
	}
	return base + "/app/projects/" + projectID
}

// SendMessage delivers a branded transactional email.
func (s *Sender) SendMessage(ctx context.Context, msg Message) error {
	to := strings.TrimSpace(msg.To)
	if to == "" {
		return nil
	}
	text := msg.Text()
	htmlBody := msg.HTML()

	if !s.cfg.Enabled() || s.client == nil {
		s.logger.Info("email (resend not configured)",
			"to", to, "subject", msg.Subject, "body", text)
		return nil
	}

	params := &resend.SendEmailRequest{
		From:    s.cfg.From,
		To:      []string{to},
		Subject: msg.Subject,
		Text:    text,
		Html:    htmlBody,
	}
	_, err := s.client.Emails.SendWithContext(ctx, params)
	if err != nil {
		return fmt.Errorf("resend: %w", err)
	}
	return nil
}

// SendOTP emails a sign-in verification code.
func (s *Sender) SendOTP(ctx context.Context, to, code string) error {
	msg := OTP(code)
	msg.To = to
	return s.SendMessage(ctx, msg)
}
