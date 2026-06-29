-- Developer workflow: needs-info status, fix notes, release links, feedback comments.

ALTER TABLE structured_bugs DROP CONSTRAINT structured_bugs_status_check;
ALTER TABLE structured_bugs
    ADD CONSTRAINT structured_bugs_status_check
    CHECK (status IN ('suggested', 'open', 'needs_info', 'fixed'));

ALTER TABLE structured_bugs ADD COLUMN fix_note text;
ALTER TABLE structured_bugs ADD COLUMN fixed_in_release_id uuid REFERENCES releases(id) ON DELETE SET NULL;

CREATE TABLE feedback_comments (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feedback_id uuid NOT NULL REFERENCES feedback(id) ON DELETE CASCADE,
    author_id   uuid NOT NULL REFERENCES users(id),
    body        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_feedback_comments_feedback ON feedback_comments(feedback_id, created_at);
