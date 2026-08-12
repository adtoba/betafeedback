package mail

import (
	"fmt"
	"html"
	"strings"
)

// Message is a plain transactional email that adapts to light/dark mode.
type Message struct {
	To        string
	Subject   string
	Preheader string
	Title     string
	Intro     string
	// Highlight is an optional large monospace callout (e.g. OTP code).
	Highlight string
	Sections  []Section
	CTALabel  string
	CTAURL    string
	Footer    string
}

// Section is a labeled block inside the email.
type Section struct {
	Label string
	Body  string
}

func (m Message) Text() string {
	var b strings.Builder
	if m.Title != "" {
		b.WriteString(m.Title)
		b.WriteString("\n\n")
	}
	if m.Intro != "" {
		b.WriteString(m.Intro)
		b.WriteString("\n\n")
	}
	if m.Highlight != "" {
		b.WriteString(m.Highlight)
		b.WriteString("\n\n")
	}
	for _, s := range m.Sections {
		if s.Label != "" {
			b.WriteString(s.Label)
			b.WriteString("\n")
		}
		b.WriteString(s.Body)
		b.WriteString("\n\n")
	}
	if m.CTAURL != "" {
		if m.CTALabel != "" {
			b.WriteString(m.CTALabel)
			b.WriteString(": ")
		}
		b.WriteString(m.CTAURL)
		b.WriteString("\n\n")
	}
	if m.Footer != "" {
		b.WriteString(m.Footer)
		b.WriteString("\n")
	}
	return strings.TrimSpace(b.String()) + "\n"
}

func (m Message) HTML() string {
	var body strings.Builder

	if m.Title != "" {
		fmt.Fprintf(&body,
			`<h1 class="t" style="margin:0 0 16px;font-size:20px;line-height:1.3;font-weight:600;color:#111111">%s</h1>`,
			html.EscapeString(m.Title),
		)
	}
	if m.Intro != "" {
		fmt.Fprintf(&body,
			`<p class="b" style="margin:0 0 20px;font-size:15px;line-height:1.5;color:#333333">%s</p>`,
			nl2br(html.EscapeString(m.Intro)),
		)
	}
	if m.Highlight != "" {
		fmt.Fprintf(&body,
			`<p class="t" style="margin:0 0 24px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:28px;letter-spacing:0.2em;font-weight:600;color:#111111">%s</p>`,
			html.EscapeString(m.Highlight),
		)
	}
	for _, s := range m.Sections {
		if s.Label != "" {
			fmt.Fprintf(&body,
				`<p class="m" style="margin:0 0 4px;font-size:12px;line-height:1.4;color:#666666">%s</p>`,
				html.EscapeString(s.Label),
			)
		}
		fmt.Fprintf(&body,
			`<p class="t" style="margin:0 0 16px;font-size:15px;line-height:1.5;color:#111111;white-space:pre-wrap">%s</p>`,
			nl2br(html.EscapeString(s.Body)),
		)
	}
	if m.CTAURL != "" && m.CTALabel != "" {
		fmt.Fprintf(&body,
			`<p style="margin:8px 0 20px"><a class="a" href="%s" style="color:#1a6fd4;font-size:15px">%s</a></p>`,
			html.EscapeString(m.CTAURL), html.EscapeString(m.CTALabel),
		)
	}

	footer := "You're receiving this because of your BetaFeedback notification settings."
	if m.Footer != "" {
		footer = m.Footer
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>%s</title>
<style>
  :root { color-scheme: light dark; }
  body { background:#ffffff; color:#111111; }
  @media (prefers-color-scheme: dark) {
    body { background:#111111 !important; color:#f2f2f2 !important; }
    .wrap { background:#111111 !important; }
    .t { color:#f2f2f2 !important; }
    .b { color:#d0d0d0 !important; }
    .m { color:#a0a0a0 !important; }
    .a { color:#6eb3ff !important; }
  }
</style>
</head>
<body style="margin:0;padding:0;background:#ffffff;color:#111111">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">%s</div>
  <div class="wrap" style="margin:0 auto;padding:28px 20px;max-width:560px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#ffffff;color:#111111">
    <p class="m" style="margin:0 0 24px;font-size:13px;color:#666666">BetaFeedback</p>
    %s
    <p class="m" style="margin:28px 0 0;font-size:12px;line-height:1.5;color:#666666">%s</p>
  </div>
</body>
</html>`,
		html.EscapeString(firstNonEmpty(m.Title, m.Subject)),
		html.EscapeString(m.Preheader),
		body.String(),
		html.EscapeString(footer),
	)
}

func nl2br(s string) string {
	return strings.ReplaceAll(s, "\n", "<br>\n")
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// OTP builds the sign-in code email.
func OTP(code string) Message {
	return Message{
		Subject:   "Your BetaFeedback sign-in code",
		Preheader: fmt.Sprintf("Your code is %s — expires in 10 minutes.", code),
		Title:     "Your sign-in code",
		Intro:     "Use this code to finish signing in to BetaFeedback. It expires in 10 minutes.",
		Highlight: code,
		Footer:    "If you didn't request this, you can ignore this email.",
	}
}

// NewFeedback builds a project feedback notification.
func NewFeedback(projectName, authorName, feedbackTitle, feedbackBody, projectURL string) Message {
	return Message{
		Subject:   fmt.Sprintf("New feedback in %s", projectName),
		Preheader: fmt.Sprintf("%s shared feedback in %s", authorName, projectName),
		Title:     "New feedback",
		Intro:     fmt.Sprintf("%s left feedback on %s.", authorName, projectName),
		Sections: []Section{
			{Label: "Title", Body: feedbackTitle},
			{Label: "Details", Body: feedbackBody},
		},
		CTALabel: "Open project",
		CTAURL:   projectURL,
	}
}

// SuggestedBug builds an AI bug-review notification.
func SuggestedBug(projectName, bugTitle, projectURL string) Message {
	return Message{
		Subject:   fmt.Sprintf("Bug to review in %s", projectName),
		Preheader: bugTitle,
		Title:     "Bug ready to review",
		Intro:     fmt.Sprintf("A structured bug draft is ready for %s. Confirm or dismiss it in the app.", projectName),
		Sections: []Section{
			{Label: "Suggested title", Body: bugTitle},
		},
		CTALabel: "Review bug",
		CTAURL:   projectURL,
	}
}

// Release builds a release announcement email.
func Release(projectName, version, notes, projectURL string) Message {
	sections := []Section{{Label: "Version", Body: version}}
	if strings.TrimSpace(notes) != "" {
		sections = append(sections, Section{Label: "Notes", Body: notes})
	}
	return Message{
		Subject:   fmt.Sprintf("%s shipped %s", projectName, version),
		Preheader: fmt.Sprintf("New release %s in %s", version, projectName),
		Title:     "New release",
		Intro:     fmt.Sprintf("%s just shipped %s.", projectName, version),
		Sections:  sections,
		CTALabel:  "View release",
		CTAURL:    projectURL,
	}
}

// TesterInvite builds an email when a creator invites someone to test their app.
func TesterInvite(projectName, fromName, message, openURL string) Message {
	sections := []Section{}
	if strings.TrimSpace(message) != "" {
		sections = append(sections, Section{Label: "Message", Body: message})
	}
	return Message{
		Subject:   fmt.Sprintf("%s invited you to test %s", fromName, projectName),
		Preheader: fmt.Sprintf("Open BetaFeedback to accept or decline testing %s.", projectName),
		Title:     "Tester invitation",
		Intro: fmt.Sprintf(
			"%s invited you to test %s on BetaFeedback. Open the app to accept or decline.",
			fromName,
			projectName,
		),
		Sections: sections,
		CTALabel: "Open BetaFeedback",
		CTAURL:   openURL,
		Footer:   "You're receiving this because someone invited you to test their app on BetaFeedback.",
	}
}

// MemberInvite builds an email when a creator invites someone by email as
// tester or developer.
func MemberInvite(projectName, fromName, role, openURL string) Message {
	roleLabel := role
	if roleLabel != "developer" {
		roleLabel = "tester"
	}
	return Message{
		Subject:   fmt.Sprintf("%s invited you to join %s", fromName, projectName),
		Preheader: fmt.Sprintf("You've been invited as a %s — accept or decline in BetaFeedback.", roleLabel),
		Title:     "You're invited",
		Intro: fmt.Sprintf(
			"%s invited you to join %s as a %s. Open BetaFeedback to accept or decline.",
			fromName,
			projectName,
			roleLabel,
		),
		CTALabel: "Open BetaFeedback",
		CTAURL:   openURL,
		Footer:   "You're receiving this because someone invited you to a project on BetaFeedback.",
	}
}

// TesterJoined notifies a creator that someone joined as a tester (invite link or
// accepted invitation). Includes the tester email for Play Console / Google Group.
func TesterJoined(projectName, testerName, testerEmail, projectURL string) Message {
	return Message{
		Subject:   fmt.Sprintf("%s joined %s", testerName, projectName),
		Preheader: fmt.Sprintf("Add %s to Play closed testing if needed.", testerEmail),
		Title:     "New tester joined",
		Intro: fmt.Sprintf(
			"%s (%s) joined %s as a tester. If you use Play closed testing or a Google Group, add this email to your allowlist.",
			testerName,
			testerEmail,
			projectName,
		),
		CTALabel: "View project",
		CTAURL:   projectURL,
		Footer:   "You're receiving this because someone joined your beta on BetaFeedback.",
	}
}
