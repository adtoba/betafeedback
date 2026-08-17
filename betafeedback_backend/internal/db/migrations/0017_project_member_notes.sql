-- Free-form notes for project members (links, install steps, credentials hints).
ALTER TABLE projects ADD COLUMN member_notes text NOT NULL DEFAULT '';
