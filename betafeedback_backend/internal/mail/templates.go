package mail

import (
	"fmt"
	"html"
	"strings"
)

// brand colors aligned with the marketing site (signal blue on navy).
const (
	colorBg      = "#070b14"
	colorSurface = "#121826"
	colorInk     = "#eef1f7"
	colorMuted   = "#a8b0c2"
	colorLine    = "rgba(238,241,247,0.12)"
	colorSignal  = "#2f8fff"
	colorSignal2 = "#1a6fd4"
	colorEmber   = "#e8943a"
	colorCodeBg  = "#0c1220"
)

// Message is a branded transactional email.
type Message struct {
	To        string
	Subject   string
	Preheader string
	Eyebrow   string
	Title     string
	Intro     string
	// Highlight is an optional large monospace callout (e.g. OTP code).
	Highlight string
	Sections  []Section
	CTALabel  string
	CTAURL    string
	Footer    string
}

// Section is a labeled block inside the email card.
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
	var sections strings.Builder
	for _, s := range m.Sections {
		label := ""
		if s.Label != "" {
			label = fmt.Sprintf(
				`<div style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:%s;margin:0 0 8px">%s</div>`,
				colorEmber, html.EscapeString(s.Label),
			)
		}
		sections.WriteString(fmt.Sprintf(
			`<tr><td style="padding:0 0 20px">%s<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.55;color:%s;white-space:pre-wrap">%s</div></td></tr>`,
			label, colorInk, nl2br(html.EscapeString(s.Body)),
		))
	}

	cta := ""
	if m.CTAURL != "" && m.CTALabel != "" {
		cta = fmt.Sprintf(`
<tr><td style="padding:8px 0 28px">
  <a href="%s" style="display:inline-block;background:linear-gradient(105deg,%s 0%%,%s 100%%);color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;text-decoration:none;padding:14px 22px;border-radius:12px">%s</a>
</td></tr>`, html.EscapeString(m.CTAURL), colorSignal2, colorSignal, html.EscapeString(m.CTALabel))
	}

	eyebrow := ""
	if m.Eyebrow != "" {
		eyebrow = fmt.Sprintf(
			`<div style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;letter-spacing:0.14em;text-transform:uppercase;color:%s;margin:0 0 12px">%s</div>`,
			colorEmber, html.EscapeString(m.Eyebrow),
		)
	}

	intro := ""
	if m.Intro != "" {
		intro = fmt.Sprintf(
			`<p style="margin:0 0 24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.55;color:%s">%s</p>`,
			colorMuted, nl2br(html.EscapeString(m.Intro)),
		)
	}

	highlight := ""
	if m.Highlight != "" {
		highlight = fmt.Sprintf(`
<tr><td style="padding:0 0 24px">
  <div style="background:%s;border:1px solid %s;border-radius:14px;padding:22px 16px;text-align:center">
    <div style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;letter-spacing:0.14em;text-transform:uppercase;color:%s;margin:0 0 10px">Code</div>
    <div style="font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:36px;letter-spacing:0.28em;font-weight:700;color:%s;line-height:1">%s</div>
  </div>
</td></tr>`, colorCodeBg, colorLine, colorEmber, colorInk, html.EscapeString(m.Highlight))
	}

	footer := "You're receiving this because of your BetaFeedback notification settings."
	if m.Footer != "" {
		footer = m.Footer
	}

	preheader := html.EscapeString(m.Preheader)
	title := html.EscapeString(m.Title)

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="supported-color-schemes" content="dark">
<title>%s</title>
</head>
<body style="margin:0;padding:0;background:%s">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">%s</div>
  <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" border="0" style="background:%s;padding:32px 16px">
    <tr><td align="center">
      <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px">
        <tr><td style="padding:0 0 20px">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
            <tr>
              <td style="width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,%s 0%%,%s 100%%);color:#fff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-align:center;vertical-align:middle;line-height:32px">B</td>
              <td style="padding-left:10px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:650;letter-spacing:-0.02em;color:%s">BetaFeedback</td>
            </tr>
          </table>
        </td></tr>
        <tr><td style="background:%s;border:1px solid %s;border-radius:18px;padding:28px 28px 8px">
          <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="padding:0 0 8px">
              %s
              <h1 style="margin:0 0 12px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:24px;line-height:1.2;letter-spacing:-0.03em;font-weight:700;color:%s">%s</h1>
              %s
            </td></tr>
            %s
            %s
            %s
          </table>
        </td></tr>
        <tr><td style="padding:22px 8px 0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:%s">
          %s
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`,
		title,
		colorBg,
		preheader,
		colorBg,
		colorSignal2, colorSignal,
		colorInk,
		colorSurface, colorLine,
		eyebrow,
		colorInk, title,
		intro,
		highlight,
		sections.String(),
		cta,
		colorMuted,
		html.EscapeString(footer),
	)
}

func nl2br(s string) string {
	return strings.ReplaceAll(s, "\n", "<br>\n")
}

// OTP builds the sign-in code email.
func OTP(code string) Message {
	return Message{
		Subject:   "Your BetaFeedback sign-in code",
		Preheader: fmt.Sprintf("Your code is %s — expires in 10 minutes.", code),
		Eyebrow:   "Sign in",
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
		Eyebrow:   "Feedback",
		Title:     "New feedback arrived",
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
		Eyebrow:   "AI draft",
		Title:     "A bug is ready to review",
		Intro:     fmt.Sprintf("BetaFeedback drafted a structured bug for %s. Confirm or dismiss it in the app.", projectName),
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
		Eyebrow:   "Release",
		Title:     "New release posted",
		Intro:     fmt.Sprintf("%s just shipped %s.", projectName, version),
		Sections:  sections,
		CTALabel:  "View release",
		CTAURL:    projectURL,
	}
}
