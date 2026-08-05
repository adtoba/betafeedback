-- Sign in with Apple: stable subject for subsequent logins (email may be omitted).
ALTER TABLE users
    ADD COLUMN apple_sub text UNIQUE;
