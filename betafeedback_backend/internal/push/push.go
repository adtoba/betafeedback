package push

import (
	"context"
	"log/slog"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Config configures FCM delivery. When [CredentialsPath] is empty, sends are
// logged instead of delivered (same pattern as SMTP in development).
type Config struct {
	CredentialsPath string
}

type Sender struct {
	client *messaging.Client
	logger *slog.Logger
}

func NewSender(cfg Config, logger *slog.Logger) (*Sender, error) {
	s := &Sender{logger: logger}
	path := strings.TrimSpace(cfg.CredentialsPath)
	if path == "" {
		return s, nil
	}

	app, err := firebase.NewApp(context.Background(), nil, option.WithCredentialsFile(path))
	if err != nil {
		return nil, err
	}
	client, err := app.Messaging(context.Background())
	if err != nil {
		return nil, err
	}
	s.client = client
	return s, nil
}

func (s *Sender) Enabled() bool {
	return s.client != nil
}

// Send delivers a push notification to each token. Invalid tokens are returned
// so the caller can prune them from the database.
func (s *Sender) Send(
	ctx context.Context,
	tokens []string,
	title, body string,
	data map[string]string,
) (invalidTokens []string, err error) {
	if len(tokens) == 0 {
		return nil, nil
	}
	if !s.Enabled() {
		s.logger.Info("push (fcm not configured)",
			"tokens", len(tokens), "title", title, "body", body, "data", data)
		return nil, nil
	}

	msg := &messaging.MulticastMessage{
		Tokens: tokens,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
	}

	resp, err := s.client.SendEachForMulticast(ctx, msg)
	if err != nil {
		return nil, err
	}

	for i, r := range resp.Responses {
		if r.Success {
			continue
		}
		if messaging.IsUnregistered(r.Error) || messaging.IsInvalidArgument(r.Error) {
			invalidTokens = append(invalidTokens, tokens[i])
		} else if r.Error != nil {
			s.logger.Error("fcm send", "err", r.Error, "token_index", i)
		}
	}
	return invalidTokens, nil
}
