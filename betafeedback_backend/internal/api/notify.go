package api

import (
	"context"
	"fmt"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func (s *Server) notifyProjectTeam(ctx context.Context, projectID, subject, body string) {
	recipients, err := s.store.ListProEmailRecipients(ctx, projectID)
	if err != nil {
		s.logger.Error("list email recipients", "err", err)
		return
	}
	for _, u := range recipients {
		if err := s.mailer.Send(ctx, u.Email, subject, body); err != nil {
			s.logger.Error("send email", "err", err, "to", u.Email)
		}
	}
}

func (s *Server) emailNewFeedback(ctx context.Context, projectID string, fb model.Feedback) {
	name, err := s.store.ProjectName(ctx, projectID)
	if err != nil {
		s.logger.Error("project name for email", "err", err)
		name = "your project"
	}
	title := "New feedback"
	if fb.Title != nil && *fb.Title != "" {
		title = *fb.Title
	}
	body := fmt.Sprintf(
		"New feedback in %s\n\nFrom: %s\nTitle: %s\n\n%s\n",
		name, fb.AuthorName, title, fb.Body,
	)
	s.notifyProjectTeam(ctx, projectID, fmt.Sprintf("New feedback in %s", name), body)
}

func (s *Server) emailSuggestedBug(ctx context.Context, projectID, bugTitle string) {
	name, err := s.store.ProjectName(ctx, projectID)
	if err != nil {
		name = "your project"
	}
	body := fmt.Sprintf(
		"A new AI-suggested bug is ready for review in %s.\n\n%s\n\nOpen BetaFeedback to confirm or dismiss it.",
		name, bugTitle,
	)
	s.notifyProjectTeam(ctx, projectID, fmt.Sprintf("Bug to review in %s", name), body)
}

func (s *Server) emailRelease(ctx context.Context, projectID, version string, notes *string) {
	name, err := s.store.ProjectName(ctx, projectID)
	if err != nil {
		name = "your project"
	}
	body := fmt.Sprintf("A new release was posted in %s.\n\nVersion: %s", name, version)
	if notes != nil && *notes != "" {
		body += fmt.Sprintf("\n\n%s", *notes)
	}
	s.notifyProjectTeam(ctx, projectID, fmt.Sprintf("%s shipped %s", name, version), body)
}
