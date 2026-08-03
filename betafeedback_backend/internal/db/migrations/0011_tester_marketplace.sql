-- Tester marketplace: opt-in profiles, invitations, and ratings.

ALTER TABLE users
    ADD COLUMN open_to_test boolean NOT NULL DEFAULT false,
    ADD COLUMN tester_bio text NOT NULL DEFAULT '';

CREATE TABLE tester_invitations (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    from_user_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message       text NOT NULL DEFAULT '',
    status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    responded_at  timestamptz
);

-- At most one pending invite per tester per project.
CREATE UNIQUE INDEX idx_tester_invites_pending
    ON tester_invitations (project_id, to_user_id)
    WHERE status = 'pending';

CREATE INDEX idx_tester_invites_to_user
    ON tester_invitations (to_user_id, created_at DESC);

CREATE INDEX idx_tester_invites_project
    ON tester_invitations (project_id, created_at DESC);

CREATE TABLE tester_ratings (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    rater_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tester_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score      smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment    text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id, rater_id, tester_id)
);

CREATE INDEX idx_tester_ratings_tester ON tester_ratings (tester_id);
