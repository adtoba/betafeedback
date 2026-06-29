-- Feedback is auto-structured into a bug on submission, but the draft lands in
-- a 'suggested' state until a developer confirms it. Confirming flips it to
-- 'open'; dismissing deletes it.
ALTER TABLE structured_bugs DROP CONSTRAINT structured_bugs_status_check;
ALTER TABLE structured_bugs
    ADD CONSTRAINT structured_bugs_status_check
    CHECK (status IN ('suggested', 'open', 'fixed'));
