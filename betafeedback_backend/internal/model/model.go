// Package model holds the domain types shared by the store and API layers.
package model

import "time"

type User struct {
	ID                 string    `json:"id"`
	Email              string    `json:"email"`
	Name               string    `json:"name"`
	AvatarHue          int       `json:"avatar_hue"`
	EmailNotifications bool      `json:"email_notifications"`
	CreatedAt          time.Time `json:"created_at"`
}

type Project struct {
	ID               string     `json:"id"`
	Name             string     `json:"name"`
	Description      string     `json:"description"`
	CreatorID        string     `json:"creator_id"`
	CreatorName      string     `json:"creator_name"`
	InviteCode       string     `json:"invite_code"`
	InviteLink       string     `json:"invite_link"`
	AppLink          *string        `json:"app_link"`
	LogoURL          *string        `json:"logo_url"`
	PlatformLinks    []PlatformLink `json:"platform_links"`
	CreatedAt        time.Time      `json:"created_at"`
	TesterCount      int            `json:"tester_count"`
	MemberCount      int            `json:"member_count"`
	LatestFeedbackAt *time.Time     `json:"latest_feedback_at"`
	LatestActivityAt *time.Time     `json:"latest_activity_at"`
	Members          []Member       `json:"members,omitempty"`
}

// PlatformLink is a per-platform test/download link for a project's build,
// e.g. {Platform: "ios", URL: "https://testflight.apple.com/join/…"}.
type PlatformLink struct {
	Platform string `json:"platform"`
	URL      string `json:"url"`
}

// InviteInfo is the public, unauthenticated summary shown on the /join page for
// an invite code.
type InviteInfo struct {
	ProjectName string `json:"project_name"`
	CreatorName string `json:"creator_name"`
	TesterCount int    `json:"tester_count"`
}

type Member struct {
	UserID    string `json:"user_id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	Role      string `json:"role"`
	AvatarHue int    `json:"avatar_hue"`
}

type Screenshot struct {
	Label string `json:"label"`
	Hue   int    `json:"hue"`
	// URL and ContentType are set for real uploaded media; empty for the older
	// placeholder thumbnails. Kind is derived from ContentType ("image"/"video").
	URL         string `json:"url,omitempty"`
	ContentType string `json:"content_type,omitempty"`
}

type FeedbackComment struct {
	ID         string    `json:"id"`
	FeedbackID string    `json:"feedback_id"`
	AuthorID   string    `json:"author_id"`
	AuthorName string    `json:"author_name"`
	Body       string    `json:"body"`
	CreatedAt  time.Time `json:"created_at"`
}

type Feedback struct {
	ID          string            `json:"id"`
	ProjectID   string            `json:"project_id"`
	AuthorID    string            `json:"author_id"`
	AuthorName  string            `json:"author_name"`
	Title       *string           `json:"title"`
	Body        string            `json:"body"`
	Device      *string           `json:"device"`
	AppVersion  *string           `json:"app_version"`
	Platform    *string           `json:"platform"`
	Screenshots []Screenshot      `json:"screenshots"`
	Comments    []FeedbackComment `json:"comments,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
}

type Activity struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	ActorID   string    `json:"actor_id"`
	ActorName string    `json:"actor_name"`
	Type      string    `json:"type"`
	Subject   string    `json:"subject"`
	Note      *string   `json:"note"`
	CreatedAt time.Time `json:"created_at"`
}

type Notification struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	Kind      string    `json:"kind"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	Read      bool      `json:"read"`
	CreatedAt time.Time `json:"created_at"`
}

type Release struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	Version   string    `json:"version"`
	Notes     *string   `json:"notes"`
	PostedBy  string    `json:"posted_by"`
	CreatedAt time.Time `json:"created_at"`
}

type StructuredBug struct {
	ID                    string     `json:"id"`
	ProjectID             string     `json:"project_id"`
	FeedbackID            *string    `json:"feedback_id"`
	Title                 string     `json:"title"`
	Steps                 []string   `json:"steps"`
	Expected              string     `json:"expected"`
	Actual                string     `json:"actual"`
	Severity              string     `json:"severity"`
	Status                string     `json:"status"`
	ReporterName          *string    `json:"reporter_name"`
	StructuredAt          time.Time  `json:"structured_at"`
	FixedAt               *time.Time `json:"fixed_at"`
	FixNote               *string    `json:"fix_note"`
	FixedInReleaseID      *string    `json:"fixed_in_release_id"`
	FixedInReleaseVersion *string    `json:"fixed_in_release_version"`
}

type TestItem struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	Title     string    `json:"title"`
	Details   *string   `json:"details"`
	CreatedAt time.Time `json:"created_at"`
}

type Subscription struct {
	Plan            string  `json:"plan"`
	Status          string  `json:"status"`
	RenewsOn        *string `json:"renews_on"`
	Seats           int     `json:"seats"`
	ProjectLimit    *int    `json:"project_limit"`
	ProjectsCreated int     `json:"projects_created"`
}
