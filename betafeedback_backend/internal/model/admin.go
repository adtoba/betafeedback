package model

import "time"

// AdminOverview is the ops dashboard KPI snapshot.
type AdminOverview struct {
	UsersTotal         int `json:"users_total"`
	UsersLast7Days     int `json:"users_last_7_days"`
	UsersLast30Days    int `json:"users_last_30_days"`
	ProjectsTotal      int `json:"projects_total"`
	FeedbackTotal      int `json:"feedback_total"`
	FeedbackLast7Days  int `json:"feedback_last_7_days"`
	FeedbackLast30Days int `json:"feedback_last_30_days"`
	BugsTotal          int `json:"bugs_total"`
	SwapsPending       int `json:"swaps_pending"`
	SwapsAccepted      int `json:"swaps_accepted"`
	SwapsFulfilled     int `json:"swaps_fulfilled"`
	SwapsDeclined      int `json:"swaps_declined"`
	SwapsCancelled     int `json:"swaps_cancelled"`
	SubsPro            int `json:"subs_pro"`
	SubsFree           int `json:"subs_free"`
	RecentActivity     []AdminActivity `json:"recent_activity"`
}

// AdminActivity is a cross-project activity row for the ops feed.
type AdminActivity struct {
	ID          string    `json:"id"`
	ProjectID   string    `json:"project_id"`
	ProjectName string    `json:"project_name"`
	ActorID     string    `json:"actor_id"`
	ActorName   string    `json:"actor_name"`
	Type        string    `json:"type"`
	Subject     string    `json:"subject"`
	Note        *string   `json:"note"`
	CreatedAt   time.Time `json:"created_at"`
}

// AdminUserRow is a paginated users-list entry.
type AdminUserRow struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	AvatarHue    int       `json:"avatar_hue"`
	Plan         string    `json:"plan"`
	ProjectCount int       `json:"project_count"`
	CreatedAt    time.Time `json:"created_at"`
}

// AdminUserDetail is the ops user detail payload.
type AdminUserDetail struct {
	User            User           `json:"user"`
	Subscription    Subscription   `json:"subscription"`
	Projects        []AdminUserProject `json:"projects"`
	RecentFeedback  []AdminFeedbackRow `json:"recent_feedback"`
	RecentSwaps     []TestSwap     `json:"recent_swaps"`
}

// AdminUserProject is a compact project membership for a user detail.
type AdminUserProject struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role string `json:"role"`
}

// AdminProjectRow is a paginated projects-list entry.
type AdminProjectRow struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	CreatorID     string    `json:"creator_id"`
	CreatorName   string    `json:"creator_name"`
	CreatorEmail  string    `json:"creator_email"`
	MemberCount   int       `json:"member_count"`
	TesterCount   int       `json:"tester_count"`
	FeedbackCount int       `json:"feedback_count"`
	CreatedAt     time.Time `json:"created_at"`
}

// AdminProjectDetail is the ops project detail payload.
type AdminProjectDetail struct {
	Project       Project           `json:"project"`
	FeedbackCount int               `json:"feedback_count"`
	BugCount      int               `json:"bug_count"`
	RecentFeedback []AdminFeedbackRow `json:"recent_feedback"`
	RecentActivity []AdminActivity  `json:"recent_activity"`
}

// AdminFeedbackRow is a cross-project feedback list entry.
type AdminFeedbackRow struct {
	ID          string    `json:"id"`
	ProjectID   string    `json:"project_id"`
	ProjectName string    `json:"project_name"`
	AuthorID    string    `json:"author_id"`
	AuthorName  string    `json:"author_name"`
	Title       *string   `json:"title"`
	Body        string    `json:"body"`
	CreatedAt   time.Time `json:"created_at"`
}

