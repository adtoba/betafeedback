import type { Member, Project } from "./types";

export function roleForProject(project: Project, userId: string): Member["role"] | null {
  if (project.creator_id === userId) return "creator";
  const member = project.members?.find((m) => m.user_id === userId);
  return member?.role ?? null;
}

export function canManageBugs(role: Member["role"] | null) {
  return role === "creator" || role === "developer";
}

export function statusLabel(status: string) {
  switch (status) {
    case "suggested":
      return "Suggested";
    case "open":
      return "Open";
    case "needs_info":
      return "Needs info";
    case "fixed":
      return "Fixed";
    default:
      return status;
  }
}

export function hueFromString(value: string) {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = value.charCodeAt(i) + ((hash << 5) - hash);
  }
  return Math.abs(hash) % 360;
}

export function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function relativeTime(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}
