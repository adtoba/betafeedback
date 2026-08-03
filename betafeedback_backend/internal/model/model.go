// Package model holds the domain types shared by the store and API layers.
package model

import "time"

type User struct {
	ID                 string    `json:"id"`
	Email              string    `json:"email"`
	Name               string    `json:"name"`
	AvatarHue          int       `json:"avatar_hue"`
	EmailNotifications bool      `json:"email_notifications"`
	PushNotifications  bool      `json:"push_notifications"`
	OpenToTest         bool      `json:"open_to_test"`
	TesterBio          string    `json:"tester_bio"`
	TesterRatingAvg    float64   `json:"tester_rating_avg"`
	TesterRatingCount  int       `json:"tester_rating_count"`
	CreatedAt          time.Time `json:"created_at"`
}

// TesterProfile is a public discovery card for users who opted into testing.
type TesterProfile struct {
	ID             string  `json:"id"`
	Name           string  `json:"name"`
	Email          string  `json:"email"`
	AvatarHue      int     `json:"avatar_hue"`
	TesterBio      string  `json:"tester_bio"`
	RatingAvg      float64 `json:"rating_avg"`
	RatingCount    int     `json:"rating_count"`
	CompletedCount int     `json:"completed_count"`
	AlreadyMember  bool    `json:"already_member,omitempty"`
	InvitePending  bool    `json:"invite_pending,omitempty"`
}

// TesterInvitation is a request for an opted-in tester to join a project.
type TesterInvitation struct {
	ID                 string     `json:"id"`
	ProjectID          string     `json:"project_id"`
	ProjectName        string     `json:"project_name"`
	ProjectDescription string     `json:"project_description"`
	ProjectLogoURL     *string    `json:"project_logo_url,omitempty"`
	TesterCount        int        `json:"tester_count"`
	FromUserID         string     `json:"from_user_id"`
	FromUserName       string     `json:"from_user_name"`
	ToUserID           string     `json:"to_user_id"`
	ToUserName         string     `json:"to_user_name"`
	Message            string     `json:"message"`
	Status             string     `json:"status"`
	CreatedAt          time.Time  `json:"created_at"`
	RespondedAt        *time.Time `json:"responded_at,omitempty"`
}

// TesterRating is a creator's score for a tester on a specific project.
type TesterRating struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	RaterID   string    `json:"rater_id"`
	TesterID  string    `json:"tester_id"`
	Score     int       `json:"score"`
	Comment   string    `json:"comment"`
	CreatedAt time.Time `json:"created_at"`
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
