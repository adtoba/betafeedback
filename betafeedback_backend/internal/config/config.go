package config

import (
	"fmt"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all runtime configuration, sourced from the environment.
type Config struct {
	Env          string
	Port         string
	DatabaseURL  string
	JWTSecret    string
	OTPDebug     bool
	OpenAIAPIKey string
	OpenAIModel  string
	// AppBaseURL is the public web origin used to build shareable links (e.g.
	// project invites).
	AppBaseURL string
	// GoogleClientID is the web OAuth client ID (dashboard + Android serverClientId).
	// Comma-separated values are allowed; the first ID is exposed as google_client_id.
	GoogleClientID string
	// GoogleIOSClientID is the iOS OAuth client ID for native Google Sign-In.
	GoogleIOSClientID string
	// AppleClientID is the iOS/macOS bundle ID used as the Sign in with Apple
	// identity token audience (e.g. com.betafeedback.app).
	AppleClientID string
	// MediaDir is the local directory where uploaded feedback attachments
	// (screenshots, recordings) are stored and served from.
	MediaDir string
	// Optional FCM push (logs instead of sending when unset).
	FirebaseCredentialsPath string
	// RevenueCat webhook Authorization header value (optional in development).
	RevenueCatWebhookAuth string
	// Entitlement identifier for Pro in the RevenueCat dashboard (default: pro).
	RevenueCatEntitlementID string
	// Optional Resend email (OTP + notifications). Logs instead when unset.
	ResendAPIKey string
	ResendFrom   string
	// AdminEmails is a case-insensitive allowlist of emails that can access
	// /v1/admin/* (comma-separated ADMIN_EMAILS env). Empty means no admins.
	AdminEmails []string
}

// Load reads configuration from the environment, optionally seeding it from a
// local .env file. It returns an error when a required value is missing.
func Load() (Config, error) {
	_ = godotenv.Load() // .env is optional; ignore if absent.

	cfg := Config{
		Env:         getenv("ENV", "development"),
		Port:        getenv("PORT", "8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
		OTPDebug:    getenv("OTP_DEBUG", "false") == "true",
		// Optional: when unset, feedback structuring falls back to local heuristics.
		OpenAIAPIKey:            os.Getenv("OPENAI_API_KEY"),
		OpenAIModel:             getenv("OPENAI_MODEL", "gpt-4o-mini"),
		AppBaseURL:              getenv("APP_BASE_URL", "https://betafeedback.com"),
		GoogleClientID:          os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleIOSClientID:       os.Getenv("GOOGLE_IOS_CLIENT_ID"),
		AppleClientID:           getenv("APPLE_CLIENT_ID", "com.betafeedback.app"),
		MediaDir:                getenv("MEDIA_DIR", "./data/media"),
		FirebaseCredentialsPath: os.Getenv("FIREBASE_CREDENTIALS_PATH"),
		RevenueCatWebhookAuth:   os.Getenv("REVENUECAT_WEBHOOK_AUTH"),
		RevenueCatEntitlementID: getenv("REVENUECAT_ENTITLEMENT_ID", "pro"),
		ResendAPIKey:            os.Getenv("RESEND_API_KEY"),
		ResendFrom:              getenv("RESEND_FROM", "BetaFeedback <noreply@betafeedback.com>"),
		AdminEmails:             parseEmailList(os.Getenv("ADMIN_EMAILS")),
	}

	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return cfg, fmt.Errorf("JWT_SECRET is required")
	}
	return cfg, nil
}

func (c Config) IsDevelopment() bool { return c.Env == "development" }

// IsAdminEmail reports whether email is in the admin allowlist.
func (c Config) IsAdminEmail(email string) bool {
	needle := strings.ToLower(strings.TrimSpace(email))
	if needle == "" {
		return false
	}
	for _, allowed := range c.AdminEmails {
		if allowed == needle {
			return true
		}
	}
	return false
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseEmailList(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		email := strings.ToLower(strings.TrimSpace(p))
		if email != "" {
			out = append(out, email)
		}
	}
	return out
}
