package config

import (
	"fmt"
	"os"

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
	// MediaDir is the local directory where uploaded feedback attachments
	// (screenshots, recordings) are stored and served from.
	MediaDir string
	// Optional FCM push (logs instead of sending when unset).
	FirebaseCredentialsPath string
	// RevenueCat webhook Authorization header value (optional in development).
	RevenueCatWebhookAuth string
	// Entitlement identifier for Pro in the RevenueCat dashboard (default: pro).
	RevenueCatEntitlementID string
	// Optional SMTP settings for Pro email notifications.
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string
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
		OpenAIAPIKey: os.Getenv("OPENAI_API_KEY"),
		OpenAIModel:  getenv("OPENAI_MODEL", "gpt-4o-mini"),
		AppBaseURL:     getenv("APP_BASE_URL", "https://betafeedback.com"),
		GoogleClientID:          os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleIOSClientID:       os.Getenv("GOOGLE_IOS_CLIENT_ID"),
		MediaDir:                getenv("MEDIA_DIR", "./data/media"),
		FirebaseCredentialsPath: os.Getenv("FIREBASE_CREDENTIALS_PATH"),
		RevenueCatWebhookAuth:   os.Getenv("REVENUECAT_WEBHOOK_AUTH"),
		RevenueCatEntitlementID: getenv("REVENUECAT_ENTITLEMENT_ID", "pro"),
		SMTPHost:     os.Getenv("SMTP_HOST"),
		SMTPPort:     getenv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     os.Getenv("SMTP_FROM"),
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

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
