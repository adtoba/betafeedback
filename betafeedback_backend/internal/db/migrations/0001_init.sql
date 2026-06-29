-- Core identity. Roles are per-project (see project_members), not global.
CREATE TABLE users (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email      text NOT NULL UNIQUE,
    name       text NOT NULL,
    avatar_hue integer NOT NULL DEFAULT 240,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    description text NOT NULL DEFAULT '',
    creator_id  uuid NOT NULL REFERENCES users(id),
    invite_code text NOT NULL UNIQUE,
    app_link    text,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_projects_creator ON projects(creator_id);

CREATE TABLE project_members (
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role       text NOT NULL CHECK (role IN ('creator', 'tester', 'developer')),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);
CREATE INDEX idx_members_user ON project_members(user_id);

CREATE TABLE feedback (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    author_id   uuid NOT NULL REFERENCES users(id),
    title       text,
    body        text NOT NULL,
    device      text,
    app_version text,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_feedback_project ON feedback(project_id, created_at DESC);

CREATE TABLE feedback_screenshots (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feedback_id uuid NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    label       text NOT NULL,
    hue         integer NOT NULL DEFAULT 200,
    position    integer NOT NULL DEFAULT 0
);
CREATE INDEX idx_screenshots_feedback ON feedback_screenshots(feedback_id);

CREATE TABLE structured_bugs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    feedback_id   uuid REFERENCES feedback(id) ON DELETE SET NULL,
    title         text NOT NULL,
    steps         jsonb NOT NULL DEFAULT '[]',
    expected      text NOT NULL DEFAULT '',
    actual        text NOT NULL DEFAULT '',
    severity      text NOT NULL DEFAULT 'Low',
    status        text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'fixed')),
    structured_by uuid REFERENCES users(id),
    structured_at timestamptz NOT NULL DEFAULT now(),
    fixed_by      uuid REFERENCES users(id),
    fixed_at      timestamptz
);
CREATE INDEX idx_bugs_project ON structured_bugs(project_id);

CREATE TABLE test_items (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title      text NOT NULL,
    details    text,
    created_by uuid REFERENCES users(id),
    position   integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_test_items_project ON test_items(project_id);

CREATE TABLE releases (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    version    text NOT NULL,
    notes      text,
    posted_by  uuid NOT NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_releases_project ON releases(project_id, created_at DESC);

CREATE TABLE activity (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    actor_id   uuid NOT NULL REFERENCES users(id),
    type       text NOT NULL CHECK (type IN ('bug_structured', 'bug_fixed', 'release_shipped')),
    subject    text NOT NULL,
    note       text,
    bug_id     uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_activity_project ON activity(project_id, created_at DESC);

CREATE TABLE notifications (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id   uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    kind         text NOT NULL,
    title        text NOT NULL,
    body         text NOT NULL,
    read         boolean NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, read, created_at DESC);

CREATE TABLE subscriptions (
    user_id       uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan          text NOT NULL DEFAULT 'free',
    status        text NOT NULL DEFAULT 'active',
    renews_on     date,
    seats         integer NOT NULL DEFAULT 1,
    project_limit integer,
    updated_at    timestamptz NOT NULL DEFAULT now()
);
