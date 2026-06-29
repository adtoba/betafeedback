-- Feedback attachments can now be real uploaded media (screenshots or screen
-- recordings) stored on disk and served via /media. url/content_type are null
-- for the older placeholder thumbnails.
ALTER TABLE feedback_screenshots ADD COLUMN url text;
ALTER TABLE feedback_screenshots ADD COLUMN content_type text;
