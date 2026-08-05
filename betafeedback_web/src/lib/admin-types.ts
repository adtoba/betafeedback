export type AdminMe = {
  id: string;
  email: string;
  name: string;
  admin: boolean;
};

export type AdminActivity = {
  id: string;
  project_id: string;
  project_name: string;
  actor_id: string;
  actor_name: string;
  type: string;
  subject: string;
  note?: string | null;
  created_at: string;
};

export type AdminOverview = {
  users_total: number;
  users_last_7_days: number;
  users_last_30_days: number;
  projects_total: number;
  feedback_total: number;
  feedback_last_7_days: number;
  feedback_last_30_days: number;
  bugs_total: number;
  swaps_pending: number;
  swaps_accepted: number;
  swaps_fulfilled: number;
  swaps_declined: number;
  swaps_cancelled: number;
  subs_pro: number;
  subs_free: number;
  recent_activity: AdminActivity[];
};

export type AdminUserRow = {
  id: string;
  email: string;
  name: string;
  avatar_hue: number;
  plan: string;
  project_count: number;
  created_at: string;
};

export type AdminUserProject = {
  id: string;
  name: string;
  role: string;
};

export type AdminFeedbackRow = {
  id: string;
  project_id: string;
  project_name: string;
  author_id: string;
  author_name: string;
  title?: string | null;
  body: string;
  created_at: string;
};

export type AdminTestSwap = {
  id: string;
  from_user_id: string;
  from_user_name: string;
  to_user_id: string;
  to_user_name: string;
  from_project_id: string;
  from_project_name: string;
  to_project_id: string;
  to_project_name: string;
  message: string;
  status: string;
  created_at: string;
  responded_at?: string | null;
  fulfilled_at?: string | null;
};

export type AdminUserDetail = {
  user: {
    id: string;
    email: string;
    name: string;
    avatar_hue: number;
    open_to_test?: boolean;
    open_to_swap?: boolean;
    tester_bio?: string;
    created_at: string;
  };
  subscription: {
    plan: string;
    status: string;
    renews_on?: string | null;
    seats: number;
    project_limit?: number | null;
    projects_created: number;
  };
  projects: AdminUserProject[];
  recent_feedback: AdminFeedbackRow[];
  recent_swaps: AdminTestSwap[];
};

export type AdminProjectRow = {
  id: string;
  name: string;
  creator_id: string;
  creator_name: string;
  creator_email: string;
  member_count: number;
  tester_count: number;
  feedback_count: number;
  created_at: string;
};

export type AdminProjectDetail = {
  project: {
    id: string;
    name: string;
    description: string;
    creator_id: string;
    creator_name: string;
    invite_code: string;
    member_count: number;
    tester_count: number;
    members?: Array<{
      user_id: string;
      name: string;
      email: string;
      role: string;
      avatar_hue: number;
    }>;
    created_at: string;
  };
  feedback_count: number;
  bug_count: number;
  recent_feedback: AdminFeedbackRow[];
  recent_activity: AdminActivity[];
};

export type AdminListResponse<T> = {
  items: T[];
  total: number;
  limit: number;
  offset: number;
};
