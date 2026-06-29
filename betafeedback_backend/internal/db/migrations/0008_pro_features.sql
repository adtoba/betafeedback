-- Pro preferences: email notifications opt-in for paid users.
ALTER TABLE users ADD COLUMN email_notifications boolean NOT NULL DEFAULT false;
