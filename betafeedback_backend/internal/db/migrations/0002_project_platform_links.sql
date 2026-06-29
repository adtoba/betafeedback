-- Projects can target multiple platforms (iOS, Android, Web, macOS, …), each
-- with its own test/download link. Stored as an array of {platform, url}.
-- The legacy single app_link column is kept for backward compatibility.
ALTER TABLE projects ADD COLUMN platform_links jsonb NOT NULL DEFAULT '[]';
