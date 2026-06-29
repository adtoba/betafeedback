// Package api wires together HTTP routing, middleware, and request handlers.
package api

import (
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/adetoba/betafeedback_backend/internal/config"
	"github.com/adetoba/betafeedback_backend/internal/mail"
	"github.com/adetoba/betafeedback_backend/internal/store"
	"github.com/adetoba/betafeedback_backend/internal/structurer"
)

type Server struct {
	cfg        config.Config
	store      *store.Store
	logger     *slog.Logger
	jwt        jwtManager
	otp        *otpStore
	structurer *structurer.Service
	mailer     *mail.Sender
}

func NewServer(cfg config.Config, pool *pgxpool.Pool, logger *slog.Logger) *Server {
	return &Server{
		cfg:    cfg,
		store:  store.New(pool, cfg.AppBaseURL),
		logger: logger,
		jwt:    jwtManager{secret: []byte(cfg.JWTSecret)},
		otp:    newOTPStore(),
		structurer: structurer.NewService(structurer.Config{
			OpenAIAPIKey: cfg.OpenAIAPIKey,
			OpenAIModel:  cfg.OpenAIModel,
		}, logger),
		mailer: mail.NewSender(mail.Config{
			Host:     cfg.SMTPHost,
			Port:     cfg.SMTPPort,
			Username: cfg.SMTPUser,
			Password: cfg.SMTPPassword,
			From:     cfg.SMTPFrom,
		}, logger),
	}
}

// Routes builds the HTTP handler, including global middleware.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", s.health)

	mux.HandleFunc("GET /v1/auth/config", s.authConfig)
	mux.HandleFunc("POST /v1/auth/email/start", s.authEmailStart)
	mux.HandleFunc("POST /v1/auth/email/verify", s.authEmailVerify)
	mux.HandleFunc("POST /v1/auth/google", s.authGoogle)

	mux.HandleFunc("GET /v1/me", s.requireAuth(s.getMe))
	mux.HandleFunc("PUT /v1/me/preferences", s.requireAuth(s.updatePreferences))

	mux.HandleFunc("GET /v1/projects", s.requireAuth(s.listProjects))
	mux.HandleFunc("POST /v1/projects", s.requireAuth(s.createProject))
	mux.HandleFunc("GET /v1/projects/{id}", s.requireAuth(s.getProject))
	mux.HandleFunc("PATCH /v1/projects/{id}", s.requireAuth(s.updateProject))
	mux.HandleFunc("POST /v1/projects/{id}/members", s.requireAuth(s.addMember))

	mux.HandleFunc("GET /v1/projects/{id}/feedback", s.requireAuth(s.listFeedback))
	mux.HandleFunc("POST /v1/projects/{id}/feedback", s.requireAuth(s.createFeedback))
	mux.HandleFunc("POST /v1/projects/{id}/feedback/{feedbackId}/comments", s.requireAuth(s.createFeedbackComment))
	mux.HandleFunc("POST /v1/projects/{id}/media", s.requireAuth(s.uploadMedia))

	mux.HandleFunc("GET /v1/projects/{id}/bugs", s.requireAuth(s.listBugs))
	mux.HandleFunc("POST /v1/projects/{id}/feedback/{feedbackId}/structure", s.requireAuth(s.structureFeedback))
	mux.HandleFunc("PATCH /v1/projects/{id}/bugs/{bugId}", s.requireAuth(s.updateBug))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/confirm", s.requireAuth(s.confirmBug))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/dismiss", s.requireAuth(s.dismissBug))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/fix", s.requireAuth(s.fixBug))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/needs-info", s.requireAuth(s.markBugNeedsInfo))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/resume", s.requireAuth(s.resumeBug))
	mux.HandleFunc("POST /v1/projects/{id}/bugs/{bugId}/reopen", s.requireAuth(s.reopenBug))

	mux.HandleFunc("GET /v1/projects/{id}/test-items", s.requireAuth(s.listTestItems))
	mux.HandleFunc("POST /v1/projects/{id}/test-items", s.requireAuth(s.addTestItem))
	mux.HandleFunc("DELETE /v1/projects/{id}/test-items/{itemId}", s.requireAuth(s.removeTestItem))

	mux.HandleFunc("GET /v1/projects/{id}/export", s.requireAuth(s.exportProject))
	mux.HandleFunc("GET /v1/projects/{id}/activity", s.requireAuth(s.listActivity))
	mux.HandleFunc("GET /v1/projects/{id}/releases", s.requireAuth(s.listReleases))
	mux.HandleFunc("POST /v1/projects/{id}/releases", s.requireAuth(s.createRelease))

	mux.HandleFunc("GET /v1/notifications", s.requireAuth(s.listNotifications))
	mux.HandleFunc("POST /v1/notifications/read", s.requireAuth(s.markNotificationsRead))

	mux.HandleFunc("GET /v1/me/subscription", s.requireAuth(s.getSubscription))
	mux.HandleFunc("PUT /v1/me/subscription", s.requireAuth(s.updateSubscription))

	// Public invite summary, consumed by the marketing site's /join page.
	mux.HandleFunc("GET /v1/invites/{code}", s.getInvite)

	// Uploaded feedback attachments (served from MediaDir).
	mux.Handle("GET /media/", s.mediaFileServer())

	return s.recoverer(s.requestLogger(mux))
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// serverError logs an internal error and returns a generic 500 to the client.
func (s *Server) serverError(w http.ResponseWriter, msg string, err error) {
	s.logger.Error(msg, "err", err)
	writeError(w, http.StatusInternalServerError, "internal server error")
}
