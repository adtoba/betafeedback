-- FCM device tokens and push notification preference.
ALTER TABLE users ADD COLUMN push_notifications boolean NOT NULL DEFAULT true;

CREATE TABLE device_tokens (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      text NOT NULL,
    platform   text NOT NULL CHECK (platform IN ('ios', 'android')),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);
