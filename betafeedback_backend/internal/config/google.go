package config

import "strings"

// GoogleWebClientID returns the primary web client ID (first when comma-separated).
func (c Config) GoogleWebClientID() string {
	ids := splitClientIDs(c.GoogleClientID)
	if len(ids) == 0 {
		return ""
	}
	return ids[0]
}

// GoogleAudiences lists every OAuth client ID allowed to sign in (web + iOS).
func (c Config) GoogleAudiences() []string {
	ids := splitClientIDs(c.GoogleClientID)
	if c.GoogleIOSClientID != "" {
		found := false
		for _, id := range ids {
			if id == c.GoogleIOSClientID {
				found = true
				break
			}
		}
		if !found {
			ids = append(ids, c.GoogleIOSClientID)
		}
	}
	return ids
}

func splitClientIDs(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	seen := make(map[string]struct{}, len(parts))
	for _, part := range parts {
		id := strings.TrimSpace(part)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}
