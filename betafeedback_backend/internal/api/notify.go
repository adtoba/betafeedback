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

func (s *Server) pushToUsers(ctx context.Context, userIDs []string, projectID, kind, title, body string) {
	tokens, err := s.store.ListDeviceTokensForUsers(ctx, userIDs)
	if err != nil {
		s.logger.Error("list device tokens", "err", err)
		return
	}
	data := map[string]string{
		"project_id": projectID,
		"kind":       kind,
	}
	invalid, err := s.pusher.Send(ctx, tokens, title, body, data)
	if err != nil {
		s.logger.Error("send push", "err", err)
		return
	}
	for _, token := range invalid {
		if err := s.store.DeleteDeviceTokenByValue(ctx, token); err != nil {
			s.logger.Error("delete stale device token", "err", err)
		}
	}
}

func (s *Server) pushToProjectDevelopers(ctx context.Context, projectID, kind, title, body string) {
	userIDs, err := s.store.ListDeveloperPushRecipients(ctx, projectID)
	if err != nil {
		s.logger.Error("list push recipients", "err", err)
		return
	}
	s.pushToUsers(ctx, userIDs, projectID, kind, title, body)
}

func (s *Server) pushToProjectMembers(ctx context.Context, projectID, excludeUserID, kind, title, body string) {
	userIDs, err := s.store.ListProjectPushRecipients(ctx, projectID, excludeUserID)
	if err != nil {
		s.logger.Error("list push recipients", "err", err)
		return
	}
	s.pushToUsers(ctx, userIDs, projectID, kind, title, body)
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
	subject := fmt.Sprintf("New feedback in %s", name)
	s.notifyProjectTeam(ctx, projectID, subject, body)

	pushBody := fmt.Sprintf("%s: %s", fb.AuthorName, title)
	s.pushToProjectDevelopers(ctx, projectID, "feedback", subject, pushBody)
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
	subject := fmt.Sprintf("Bug to review in %s", name)
	s.notifyProjectTeam(ctx, projectID, subject, body)
	s.pushToProjectDevelopers(ctx, projectID, "bug", subject, bugTitle)
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

func (s *Server) pushRelease(ctx context.Context, projectID, posterID, projectName, version string, notes *string) {
	title := fmt.Sprintf("New release in %s", projectName)
	body := version
	if notes != nil && *notes != "" {
		body = fmt.Sprintf("%s — %s", version, *notes)
	}
	s.pushToProjectMembers(ctx, projectID, posterID, "release", title, body)
}
