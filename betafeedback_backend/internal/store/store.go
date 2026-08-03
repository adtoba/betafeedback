// Package store contains the Postgres-backed persistence layer.
package store

import (
	"errors"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNotFound is returned when a requested row does not exist.
var ErrNotFound = errors.New("not found")

// ErrConflict is returned when an action violates a business rule or unique constraint.
var ErrConflict = errors.New("conflict")

// ErrForbidden is returned when the caller is not allowed to perform the action.
var ErrForbidden = errors.New("forbidden")

func isUniqueViolation(err error) bool {
	if err == nil {
		return false
	}
	// pgx wraps Postgres SQLSTATE 23505 for unique_violation.
	return strings.Contains(err.Error(), "23505") ||
		strings.Contains(err.Error(), "unique") ||
		strings.Contains(err.Error(), "duplicate key")
}
type Store struct {
	pool       *pgxpool.Pool
	appBaseURL string
}

// New builds a Store. appBaseURL is the public web origin used for shareable
// links such as project invites (e.g. "https://betafeedback.com").
func New(pool *pgxpool.Pool, appBaseURL string) *Store {
	return &Store{
		pool:       pool,
		appBaseURL: strings.TrimRight(appBaseURL, "/"),
	}
}

// InviteLink builds the shareable join URL for an invite code.
func (s *Store) InviteLink(code string) string {
	return s.appBaseURL + "/join/" + code
}
