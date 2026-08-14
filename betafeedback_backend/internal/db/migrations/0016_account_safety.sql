-- Account deletion support plus report / block for marketplace and UGC.

CREATE TABLE user_blocks (
    blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
);

CREATE INDEX idx_user_blocks_blocked ON user_blocks (blocked_id);

CREATE TABLE user_reports (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason           text NOT NULL
                     CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'other')),
    details          text NOT NULL DEFAULT '',
    created_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (reporter_id <> reported_user_id)
);

CREATE INDEX idx_user_reports_created ON user_reports (created_at DESC);
CREATE INDEX idx_user_reports_reported ON user_reports (reported_user_id, created_at DESC);
