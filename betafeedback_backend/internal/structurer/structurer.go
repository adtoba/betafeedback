// Package structurer turns raw tester feedback into a structured bug report
// using simple heuristics (a stand-in for an LLM call).
package structurer

import (
	"regexp"
	"strings"
)

// Result is the structured output for a piece of feedback.
type Result struct {
	Title    string
	Steps    []string
	Expected string
	Actual   string
	Severity string
}

var (
	splitRe  = regexp.MustCompile(`[.!?\n]+`)
	shouldRe = regexp.MustCompile(`(?i)should[^.!?]*`)
)

// nonBugSignals mark feedback that is a feature request, question, or praise
// rather than a defect — these should not be auto-structured into a bug.
var nonBugSignals = []string{
	"feature request", "would be nice", "would be great", "it would help",
	"please add", "can you add", "could you add", "wish list", "wishlist",
	"suggestion", "i suggest", "nice to have", "love the", "love this",
	"great app", "thank you", "thanks for", "how do i", "how can i",
}

// bugSignals are words typical of a defect report.
var bugSignals = []string{
	"crash", "error", "broken", "bug", "doesn't work", "does not work",
	"not working", "fails", "failed", "failing", "freeze", "frozen", "hang",
	"wrong", "can't", "cannot", "unable", "issue", "glitch", "missing",
	"blank", "stuck", "won't", "should", "expected",
}

// IsBugLike decides whether a piece of feedback looks like a defect worth
// auto-structuring. It errs toward structuring: anything not clearly a feature
// request, question, or praise is treated as a candidate bug.
func IsBugLike(title, body string) bool {
	text := strings.ToLower(strings.TrimSpace(title + " " + body))
	for _, kw := range nonBugSignals {
		if strings.Contains(text, kw) {
			return false
		}
	}
	for _, kw := range bugSignals {
		if strings.Contains(text, kw) {
			return true
		}
	}
	// No strong signal either way: treat substantive reports as bug-like, but
	// skip one-liners that carry no defect language.
	return len(text) >= 40
}

// Structure analyzes feedback text (an optional title plus a body) and returns
// a developer-friendly bug report.
func Structure(title, body string) Result {
	raw := strings.TrimSpace(body)
	if t := strings.TrimSpace(title); t != "" {
		raw = t + ". " + raw
	}

	var lines []string
	for _, part := range splitRe.Split(raw, -1) {
		if p := strings.TrimSpace(part); p != "" {
			lines = append(lines, p)
		}
	}

	return Result{
		Title:    extractTitle(lines),
		Steps:    extractSteps(lines),
		Expected: inferExpected(raw),
		Actual:   inferActual(lines, raw),
		Severity: inferSeverity(raw),
	}
}

func extractTitle(lines []string) string {
	if len(lines) == 0 {
		return "Untitled bug report"
	}
	first := lines[0]
	if len(first) <= 60 {
		return first
	}
	return first[:57] + "..."
}

func extractSteps(lines []string) []string {
	if len(lines) <= 1 {
		return []string{"Open the app", "Navigate to the affected screen", "Observe the issue"}
	}
	if len(lines) > 4 {
		lines = lines[:4]
	}
	return lines
}

func inferSeverity(raw string) string {
	lower := strings.ToLower(raw)
	switch {
	case strings.Contains(lower, "crash"), strings.Contains(lower, "data loss"), strings.Contains(lower, "cannot login"):
		return "Critical"
	case strings.Contains(lower, "broken"), strings.Contains(lower, "doesn't work"), strings.Contains(lower, "error"):
		return "High"
	case strings.Contains(lower, "slow"), strings.Contains(lower, "confusing"):
		return "Medium"
	default:
		return "Low"
	}
}

func inferExpected(raw string) string {
	if match := shouldRe.FindString(raw); match != "" {
		match = strings.TrimSpace(match)
		if match != "" {
			return strings.ToUpper(match[:1]) + match[1:] + "."
		}
	}
	return "The feature should work as designed without errors."
}

func inferActual(lines []string, raw string) string {
	if len(lines) > 1 {
		return lines[len(lines)-1]
	}
	if len(raw) > 120 {
		return raw[:117] + "..."
	}
	return raw
}
