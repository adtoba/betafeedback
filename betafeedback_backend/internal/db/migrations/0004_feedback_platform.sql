-- The platform a tester was on when submitting feedback (e.g. 'ios', 'android'),
-- chosen from the platforms the project creator configured. Nullable.
ALTER TABLE feedback ADD COLUMN platform text;
