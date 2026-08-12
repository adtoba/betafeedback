package api

import (
	"context"
	"fmt"
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/mail"
	"github.com/adetoba/betafeedback_backend/internal/model"
)

func (s *Server) notifyProjectTeam(ctx context.Context, projectID string, msg mail.Message) {
	recipients, err := s.store.ListProEmailRecipients(ctx, projectID)
	if err != nil {
		s.logger.Error("list email recipients", "err", err)
		return
	}
	for _, u := range recipients {
		msg.To = u.Email
		if err := s.mailer.SendMessage(ctx, msg); err != nil {
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
	msg := mail.NewFeedback(name, fb.AuthorName, title, fb.Body, s.mailer.ProjectURL(projectID))
	s.notifyProjectTeam(ctx, projectID, msg)

	subject := fmt.Sprintf("New feedback in %s", name)
	pushBody := fmt.Sprintf("%s: %s", fb.AuthorName, title)
	s.pushToProjectDevelopers(ctx, projectID, "feedback", subject, pushBody)
}

func (s *Server) emailSuggestedBug(ctx context.Context, projectID, bugTitle string) {
	name, err := s.store.ProjectName(ctx, projectID)
	if err != nil {
		name = "your project"
	}
	msg := mail.SuggestedBug(name, bugTitle, s.mailer.ProjectURL(projectID))
	s.notifyProjectTeam(ctx, projectID, msg)
	s.pushToProjectDevelopers(ctx, projectID, "bug", msg.Subject, bugTitle)
}

func (s *Server) emailRelease(ctx context.Context, projectID, version string, notes *string) {
	name, err := s.store.ProjectName(ctx, projectID)
	if err != nil {
		name = "your project"
	}
	noteText := ""
	if notes != nil {
		noteText = *notes
	}
	msg := mail.Release(name, version, noteText, s.mailer.ProjectURL(projectID))
	s.notifyProjectTeam(ctx, projectID, msg)
}

func (s *Server) pushRelease(ctx context.Context, projectID, posterID, projectName, version string, notes *string) {
	title := fmt.Sprintf("New release in %s", projectName)
	body := version
	if notes != nil && *notes != "" {
		body = fmt.Sprintf("%s — %s", version, *notes)
	}
	s.pushToProjectMembers(ctx, projectID, posterID, "release", title, body)
}

func (s *Server) emailTesterInvite(ctx context.Context, toUserID string, inv model.TesterInvitation) {
	user, err := s.store.GetUser(ctx, toUserID)
	if err != nil {
		s.logger.Error("load invitee for email", "err", err)
		return
	}
	fromName := inv.FromUserName
	if fromName == "" {
		fromName = "A creator"
	}
	openURL := s.mailer.AppBaseURL()
	msg := mail.TesterInvite(inv.ProjectName, fromName, inv.Message, openURL)
	msg.To = user.Email
	if err := s.mailer.SendMessage(ctx, msg); err != nil {
		s.logger.Error("send tester invite email", "err", err, "to", user.Email)
	}
}

func (s *Server) emailMemberInvite(ctx context.Context, inv model.TesterInvitation) {
	user, err := s.store.GetUser(ctx, inv.ToUserID)
	if err != nil {
		s.logger.Error("load invitee for email", "err", err)
		return
	}
	fromName := inv.FromUserName
	if fromName == "" {
		fromName = "A creator"
	}
	openURL := s.mailer.AppBaseURL()
	msg := mail.MemberInvite(inv.ProjectName, fromName, inv.Role, openURL)
	msg.To = user.Email
	if err := s.mailer.SendMessage(ctx, msg); err != nil {
		s.logger.Error("send member invite email", "err", err, "to", user.Email)
	}
}

func (s *Server) notifyTesterJoined(ctx context.Context, project model.Project, tester model.User) {
	creatorID := project.CreatorID
	testerName := strings.TrimSpace(tester.Name)
	if testerName == "" {
		testerName = tester.Email
	}

	s.pushToUsers(ctx, []string{creatorID}, project.ID, "tester_joined",
		"New tester joined",
		fmt.Sprintf("%s joined %s — add %s to Play if needed", testerName, project.Name, tester.Email))

	creator, err := s.store.GetUser(ctx, creatorID)
	if err != nil {
		s.logger.Error("load creator for tester joined email", "err", err)
		return
	}
	msg := mail.TesterJoined(project.Name, testerName, tester.Email, s.mailer.ProjectURL(project.ID))
	msg.To = creator.Email
	if err := s.mailer.SendMessage(ctx, msg); err != nil {
		s.logger.Error("send tester joined email", "err", err, "to", creator.Email)
	}
}
