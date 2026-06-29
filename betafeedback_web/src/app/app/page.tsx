"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { DashboardHeader, RequireAuth } from "@/components/dashboard/DashboardHeader";
import { apiRequest } from "@/lib/api-client";
import { canManageBugs, hueFromString, initials, roleForProject } from "@/lib/project-utils";
import { useAuth } from "@/context/auth-context";
import type { Project } from "@/lib/types";

function UsersIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}

function FlaskIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M9 3h6M10 3v6.5L5 18a2 2 0 0 0 1.8 3h10.4A2 2 0 0 0 19 18l-5-8.5V3" />
    </svg>
  );
}

export default function AppHomePage() {
  const { token, user } = useAuth();
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await apiRequest<{ projects: Project[] }>("/v1/projects", { token });
        if (cancelled) return;
        const detailed = await Promise.all(
          res.projects.map((p) => apiRequest<Project>(`/v1/projects/${p.id}`, { token })),
        );
        if (!cancelled) setProjects(detailed);
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Could not load projects");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const devProjects = user
    ? projects.filter((p) => canManageBugs(roleForProject(p, user.id)))
    : [];

  return (
    <RequireAuth>
      <DashboardHeader title="Projects" />
      <main className="dash-main">
        <div className="dash-page-head">
          <h1>Your projects</h1>
          <p>
            {loading
              ? "Loading your projects…"
              : devProjects.length > 0
                ? `${devProjects.length} project${devProjects.length === 1 ? "" : "s"} you can manage.`
                : "Projects you develop will appear here."}
          </p>
        </div>

        {loading && (
          <div className="dash-loading">
            <div className="spinner" role="status" aria-label="Loading projects" />
          </div>
        )}
        {error && <p className="dash-error">{error}</p>}
        {!loading && !error && devProjects.length === 0 && (
          <div className="dash-empty">
            <div className="dash-empty__icon" aria-hidden="true">
              📦
            </div>
            <h2>No developer projects yet</h2>
            <p>Create a project in the mobile app, or ask a creator to invite you as a developer.</p>
          </div>
        )}
        {!loading && devProjects.length > 0 && (
          <div className="dash-grid">
            {devProjects.map((project) => {
              const role = user ? roleForProject(project, user.id) : null;
              return (
                <Link key={project.id} href={`/app/projects/${project.id}`} className="dash-project card">
                  <div className="dash-project__top">
                    <span
                      className="dash-avatar dash-avatar--lg"
                      style={{ "--hue": hueFromString(project.id) } as React.CSSProperties}
                      aria-hidden="true"
                    >
                      {initials(project.name)}
                    </span>
                    {role && <span className="dash-tag">{role}</span>}
                  </div>
                  <h2>{project.name}</h2>
                  {project.description && <p>{project.description}</p>}
                  <div className="dash-project__meta">
                    <span className="dash-metric">
                      <UsersIcon />
                      {project.member_count} members
                    </span>
                    <span className="dash-metric">
                      <FlaskIcon />
                      {project.tester_count} testers
                    </span>
                  </div>
                  <span className="dash-project__cta">Open dashboard →</span>
                </Link>
              );
            })}
          </div>
        )}
      </main>
    </RequireAuth>
  );
}
