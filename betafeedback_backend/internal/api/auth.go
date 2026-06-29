package api

import (
	"crypto/rand"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	tokenTTL = 7 * 24 * time.Hour
	otpTTL   = 10 * time.Minute
)

// jwtManager issues and verifies signed session tokens.
type jwtManager struct {
	secret []byte
}

func (m jwtManager) issue(userID string) (string, error) {
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Subject:   userID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(tokenTTL)),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(m.secret)
}

func (m jwtManager) parse(token string) (string, error) {
	claims := &jwt.RegisteredClaims{}
	parsed, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return m.secret, nil
	})
	if err != nil || !parsed.Valid {
		return "", fmt.Errorf("invalid token")
	}
	return claims.Subject, nil
}

// otpStore holds short-lived email verification codes in memory.
type otpStore struct {
	mu    sync.Mutex
	codes map[string]otpEntry
}

type otpEntry struct {
	code    string
	expires time.Time
}

func newOTPStore() *otpStore {
	return &otpStore{codes: make(map[string]otpEntry)}
}

func (o *otpStore) generate(email string) string {
	code := randomCode()
	o.mu.Lock()
	o.codes[strings.ToLower(email)] = otpEntry{code: code, expires: time.Now().Add(otpTTL)}
	o.mu.Unlock()
	return code
}

func (o *otpStore) verify(email, code string) bool {
	key := strings.ToLower(email)
	o.mu.Lock()
	defer o.mu.Unlock()
	entry, ok := o.codes[key]
	if !ok || time.Now().After(entry.expires) || entry.code != code {
		return false
	}
	delete(o.codes, key)
	return true
}

func randomCode() string {
	b := make([]byte, 3)
	if _, err := rand.Read(b); err != nil {
		return "000000"
	}
	n := (int(b[0])<<16 | int(b[1])<<8 | int(b[2])) % 1000000
	return fmt.Sprintf("%06d", n)
}

// --- Handlers ---

type startEmailRequest struct {
	Email string `json:"email"`
}

func (s *Server) authEmailStart(w http.ResponseWriter, r *http.Request) {
	var req startEmailRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	email := normalizeEmail(req.Email)
	if !validEmail(email) {
		writeError(w, http.StatusBadRequest, "a valid email is required")
		return
	}

	code := s.otp.generate(email)
	// A real deployment emails the code here. In development we log it (and
	// optionally return it) so the flow is testable without a mail provider.
	s.logger.Info("otp issued", "email", email, "code", code)

	resp := map[string]any{"expires_in": int(otpTTL.Seconds())}
	if s.cfg.OTPDebug {
		resp["debug_code"] = code
	}
	writeJSON(w, http.StatusOK, resp)
}

type verifyEmailRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

func (s *Server) authEmailVerify(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := decode(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	email := normalizeEmail(req.Email)
	if !s.otp.verify(email, strings.TrimSpace(req.Code)) {
		writeError(w, http.StatusUnauthorized, "invalid or expired code")
		return
	}

	user, err := s.store.UpsertUser(r.Context(), email, nameFromEmail(email), avatarHue(email))
	if err != nil {
		s.serverError(w, "upsert user", err)
		return
	}
	token, err := s.jwt.issue(user.ID)
	if err != nil {
		s.serverError(w, "issue token", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "user": user})
}
