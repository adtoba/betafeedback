package store

import (
	"context"
	"encoding/csv"
	"fmt"
	"strings"
	"time"
)

// ExportFeedbackCSV returns feedback rows as CSV text for a project.
func (s *Store) ExportFeedbackCSV(ctx context.Context, projectID string) (string, error) {
	items, err := s.ListFeedback(ctx, projectID)
	if err != nil {
		return "", err
	}

	var b strings.Builder
	w := csv.NewWriter(&b)
	_ = w.Write([]string{
		"id", "created_at", "author", "title", "body", "platform", "device", "app_version",
	})
	for _, f := range items {
		title := ""
		if f.Title != nil {
			title = *f.Title
		}
		platform, device, version := "", "", ""
		if f.Platform != nil {
			platform = *f.Platform
		}
		if f.Device != nil {
			device = *f.Device
		}
		if f.AppVersion != nil {
			version = *f.AppVersion
		}
		_ = w.Write([]string{
			f.ID,
			f.CreatedAt.Format(time.RFC3339),
			f.AuthorName,
			title,
			f.Body,
			platform,
			device,
			version,
		})
	}
	w.Flush()
	return b.String(), w.Error()
}

// ExportBugsCSV returns structured bugs as CSV text for a project.
func (s *Store) ExportBugsCSV(ctx context.Context, projectID string) (string, error) {
	bugs, err := s.ListBugs(ctx, projectID)
	if err != nil {
		return "", err
	}

	var b strings.Builder
	w := csv.NewWriter(&b)
	_ = w.Write([]string{
		"id", "status", "severity", "title", "steps", "expected", "actual",
		"reporter", "structured_at", "fixed_at", "fix_note", "fixed_in_release",
	})
	for _, bug := range bugs {
		reporter := ""
		if bug.ReporterName != nil {
			reporter = *bug.ReporterName
		}
		fixedAt := ""
		if bug.FixedAt != nil {
			fixedAt = bug.FixedAt.Format(time.RFC3339)
		}
		fixNote := ""
		if bug.FixNote != nil {
			fixNote = *bug.FixNote
		}
		release := ""
		if bug.FixedInReleaseVersion != nil {
			release = *bug.FixedInReleaseVersion
		}
		_ = w.Write([]string{
			bug.ID,
			bug.Status,
			bug.Severity,
			bug.Title,
			strings.Join(bug.Steps, " | "),
			bug.Expected,
			bug.Actual,
			reporter,
			bug.StructuredAt.Format(time.RFC3339),
			fixedAt,
			fixNote,
			release,
		})
	}
	w.Flush()
	return b.String(), w.Error()
}

// ProjectName returns a project's display name.
func (s *Store) ProjectName(ctx context.Context, projectID string) (string, error) {
	var name string
	err := s.pool.QueryRow(ctx, `SELECT name FROM projects WHERE id = $1`, projectID).Scan(&name)
	if err != nil {
		return "", fmt.Errorf("project name: %w", err)
	}
	return name, nil
}
