export type User = {
  id: string;
  email: string;
  name: string;
  avatar_hue: number;
  email_notifications?: boolean;
  created_at?: string;
};

export type Member = {
  user_id: string;
  name: string;
  email: string;
  role: "creator" | "developer" | "tester";
  avatar_hue: number;
};

export type PlatformLink = {
  platform: string;
  url: string;
};

export type Project = {
  id: string;
  name: string;
  description: string;
  creator_id: string;
  creator_name: string;
  invite_code: string;
  invite_link: string;
  app_link?: string | null;
  logo_url?: string | null;
  platform_links?: PlatformLink[];
  tester_count: number;
  member_count: number;
  members?: Member[];
  created_at: string;
};

export type BugStatus = "suggested" | "open" | "needs_info" | "fixed";

export type StructuredBug = {
  id: string;
  project_id: string;
  feedback_id?: string | null;
  title: string;
  steps: string[];
  expected: string;
  actual: string;
  severity: string;
  status: BugStatus;
  reporter_name?: string | null;
  structured_at: string;
  fixed_at?: string | null;
  fix_note?: string | null;
  fixed_in_release_id?: string | null;
  fixed_in_release_version?: string | null;
};

export type Release = {
  id: string;
  project_id: string;
  version: string;
  notes?: string | null;
  posted_by: string;
  created_at: string;
};

export type Activity = {
  id: string;
  project_id: string;
  actor_id: string;
  actor_name: string;
  type: string;
  subject: string;
  note?: string | null;
  created_at: string;
};

export type Feedback = {
  id: string;
  project_id: string;
  author_id: string;
  author_name: string;
  title?: string | null;
  body: string;
  device?: string | null;
  app_version?: string | null;
  platform?: string | null;
  created_at: string;
};

export type AuthConfig = {
  google_client_id: string;
};
