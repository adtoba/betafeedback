package mail

import (
	"strings"

	"github.com/adetoba/betafeedback_backend/internal/model"
)

func platformLabel(platform string) string {
	switch strings.ToLower(strings.TrimSpace(platform)) {
	case "ios":
		return "iOS"
	case "android":
		return "Android"
	case "web":
		return "Web"
	case "macos":
		return "macOS"
	case "windows":
		return "Windows"
	case "linux":
		return "Linux"
	default:
		if platform == "" {
			return "Link"
		}
		return strings.ToUpper(platform[:1]) + platform[1:]
	}
}

// ProjectBuildLinkSections collects download / access URLs configured on a
// project into labeled email sections.
func ProjectBuildLinkSections(project model.Project) []Section {
	var sections []Section
	seen := map[string]bool{}

	add := func(label, url string) {
		url = strings.TrimSpace(url)
		if url == "" || seen[url] {
			return
		}
		seen[url] = true
		sections = append(sections, Section{Label: label, Body: url})
	}

	for _, link := range project.PlatformLinks {
		add(platformLabel(link.Platform), link.URL)
	}
	if project.AppLink != nil {
		add("App link", *project.AppLink)
	}
	if project.GoogleGroupJoinURL != nil {
		add("Google Group", *project.GoogleGroupJoinURL)
	}
	return sections
}

// TesterWelcome emails a tester who just joined with links to get the product
// build and a CTA back into BetaFeedback.
func TesterWelcome(projectName, projectURL string, linkSections []Section, memberNotes string) Message {
	intro := "You're all set to test " + projectName + ". "
	if len(linkSections) > 0 || strings.TrimSpace(memberNotes) != "" {
		intro += "Use the details below to get the app, then open BetaFeedback to file reports."
	} else {
		intro += "Open BetaFeedback to see project details and file reports. " +
			"If you need a download link, ask the project creator."
	}

	sections := append([]Section{}, linkSections...)
	if notes := strings.TrimSpace(memberNotes); notes != "" {
		sections = append(sections, Section{Label: "Getting started", Body: notes})
	}

	return Message{
		Subject:   "You're in — get started with " + projectName,
		Preheader: "Download links and next steps for " + projectName + ".",
		Title:     "Welcome to " + projectName,
		Intro:     intro,
		Sections:  sections,
		CTALabel:  "Open project in BetaFeedback",
		CTAURL:    projectURL,
		Footer:    "You're receiving this because you joined a project on BetaFeedback.",
	}
}
