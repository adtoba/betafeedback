package api

import (
	"crypto/rand"
	"net/http"
	"regexp"
	"strings"
)

var emailRegex = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validEmail(email string) bool {
	return emailRegex.MatchString(email)
}

// nameFromEmail derives a friendly default display name from an address, e.g.
// "ada.lovelace@x.com" -> "Ada Lovelace".
func nameFromEmail(email string) string {
	local, _, _ := strings.Cut(email, "@")
	local = strings.NewReplacer(".", " ", "_", " ", "-", " ").Replace(local)
	fields := strings.Fields(local)
	for i, f := range fields {
		fields[i] = strings.ToUpper(f[:1]) + f[1:]
	}
	if len(fields) == 0 {
		return "Member"
	}
	return strings.Join(fields, " ")
}

// avatarHue picks a stable hue (0-359) from an email for avatar colors.
func avatarHue(email string) int {
	sum := 0
	for _, r := range email {
		sum += int(r)
	}
	return (sum * 13) % 360
}

// generateInviteCode builds a slug-plus-random invite code from a project name.
func generateInviteCode(name string) string {
	slug := strings.ToLower(strings.TrimSpace(name))
	slug = regexp.MustCompile(`[^a-z0-9]+`).ReplaceAllString(slug, "-")
	slug = strings.Trim(slug, "-")
	if slug == "" {
		slug = "project"
	}
	if i := strings.IndexByte(slug, '-'); i > 0 {
		slug = slug[:i]
	}
	return slug + "-" + randomToken(4)
}

const tokenAlphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

func randomToken(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return strings.Repeat("0", n)
	}
	for i := range b {
		b[i] = tokenAlphabet[int(b[i])%len(tokenAlphabet)]
	}
	return string(b)
}

// optionalString trims a string and returns nil when empty, for nullable fields.
func optionalString(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}

// requireMember resolves the caller's role in a project, writing the
// appropriate error response and returning ok=false when they lack access.
func (s *Server) requireMember(w http.ResponseWriter, r *http.Request, projectID, userID string) (string, bool) {
	role, err := s.store.MemberRole(r.Context(), projectID, userID)
	if err != nil {
		// Treat "not a member" and "no such project" alike to avoid leaking
		// which projects exist.
		writeError(w, http.StatusNotFound, "project not found")
		return "", false
	}
	return role, true
}
