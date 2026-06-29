package mail

import (
	"context"
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"
)

// Config configures outbound email. When [Enabled] is false, sends are logged
// instead of delivered (same pattern as OTP in development).
type Config struct {
	Host     string
	Port     string
	Username string
	Password string
	From     string
}

type Sender struct {
	cfg    Config
	logger *slog.Logger
}

func NewSender(cfg Config, logger *slog.Logger) *Sender {
	return &Sender{cfg: cfg, logger: logger}
}

func (c Config) Enabled() bool {
	return strings.TrimSpace(c.Host) != "" && strings.TrimSpace(c.From) != ""
}

// Send delivers a plain-text email. No-op (with a log line) when SMTP is unset.
func (s *Sender) Send(_ context.Context, to, subject, body string) error {
	to = strings.TrimSpace(to)
	if to == "" {
		return nil
	}
	if !s.cfg.Enabled() {
		s.logger.Info("email (smtp not configured)",
			"to", to, "subject", subject, "body", body)
		return nil
	}

	msg := strings.Join([]string{
		"From: " + s.cfg.From,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	addr := fmt.Sprintf("%s:%s", s.cfg.Host, defaultPort(s.cfg.Port))
	auth := smtp.PlainAuth("", s.cfg.Username, s.cfg.Password, s.cfg.Host)
	return smtp.SendMail(addr, auth, s.cfg.From, []string{to}, []byte(msg))
}

func defaultPort(port string) string {
	if strings.TrimSpace(port) == "" {
		return "587"
	}
	return port
}
