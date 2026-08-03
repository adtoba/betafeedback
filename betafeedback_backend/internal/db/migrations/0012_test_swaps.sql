-- Test-for-test paired swaps between project creators.

ALTER TABLE users
    ADD COLUMN open_to_swap boolean NOT NULL DEFAULT false;

CREATE TABLE test_swaps (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    to_project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    message          text NOT NULL DEFAULT '',
    status           text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'fulfilled')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    responded_at     timestamptz,
    fulfilled_at     timestamptz,
    CHECK (from_user_id <> to_user_id),
    CHECK (from_project_id <> to_project_id)
);

-- At most one pending swap per project pair (either direction).
CREATE UNIQUE INDEX idx_test_swaps_pending_pair
    ON test_swaps (LEAST(from_project_id, to_project_id), GREATEST(from_project_id, to_project_id))
    WHERE status = 'pending';

CREATE INDEX idx_test_swaps_to_user
    ON test_swaps (to_user_id, created_at DESC);

CREATE INDEX idx_test_swaps_from_user
    ON test_swaps (from_user_id, created_at DESC);

CREATE INDEX idx_test_swaps_status
    ON test_swaps (status) WHERE status IN ('pending', 'accepted');
