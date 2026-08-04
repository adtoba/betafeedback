-- Role-aware project member invitations (email invites for tester/developer).
-- Marketplace tester invites keep role = 'tester' by default.

ALTER TABLE tester_invitations
    ADD COLUMN role text NOT NULL DEFAULT 'tester'
    CHECK (role IN ('tester', 'developer'));
