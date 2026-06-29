"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";

import { ActivityPanel } from "@/components/dashboard/ActivityPanel";
import { BugBoard } from "@/components/dashboard/BugBoard";
import { DashboardHeader, RequireAuth } from "@/components/dashboard/DashboardHeader";
import { FeedbackPanel } from "@/components/dashboard/FeedbackPanel";
import { ProjectOverview } from "@/components/dashboard/ProjectOverview";
import { ApiError, apiRequest, downloadExport } from "@/lib/api-client";
import { canManageBugs, roleForProject } from "@/lib/project-utils";
import { useAuth } from "@/context/auth-context";
import type { Activity, Feedback, Project } from "@/lib/types";

type Tab = "bugs" | "activity" | "feedback";

export default function ProjectPage() {
  const params = useParams<{ id: string }>();
  const projectId = params.id;
  const { token, user } = useAuth();
  const [project, setProject] = useState<Project | null>(null);
  const [tab, setTab] = useState<Tab>("bugs");
  const [activity, setActivity] = useState<Activity[]>([]);
  const [feedback, setFeedback] = useState<Feedback[]>([]);
  const [openBugs, setOpenBugs] = useState(0);
  const [loading, setLoading] = useState(true);
  const [tabLoading, setTabLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!token || !projectId) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await apiRequest<Project>(`/v1/projects/${projectId}`, { token });
        if (!cancelled) setProject(data);
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Could not load project");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token, projectId]);

  useEffect(() => {
    if (!token || !projectId || tab === "bugs") return;
    let cancelled = false;
    (async () => {
      setTabLoading(true);
      try {
        if (tab === "activity") {
          const res = await apiRequest<{ activity: Activity[] }>(
            `/v1/projects/${projectId}/activity`,
            { token },
          );
          if (!cancelled) setActivity(res.activity);
        } else {
          const res = await apiRequest<{ feedback: Feedback[] }>(
            `/v1/projects/${projectId}/feedback`,
            { token },
          );
          if (!cancelled) setFeedback(res.feedback);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Could not load data");
        }
      } finally {
        if (!cancelled) setTabLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token, projectId, tab]);

  const onOpenCountChange = useCallback((count: number) => {
    setOpenBugs(count);
  }, []);

  async function copyInvite() {
    if (!project?.invite_link) return;
    await navigator.clipboard.writeText(project.invite_link);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2000);
  }

  async function handleExport(type: "bugs" | "feedback") {
    if (!token || !projectId) return;
    setExportError(null);
    try {
      await downloadExport(projectId, type, token);
    } catch (err) {
      if (err instanceof ApiError && err.status === 402) {
        setExportError("Export is available on the Pro plan.");
      } else {
        setExportError(err instanceof Error ? err.message : "Export failed");
      }
    }
  }

  const role = user && project ? roleForProject(project, user.id) : null;
  const manageable = canManageBugs(role);

  return (
    <RequireAuth>
      <DashboardHeader title={project?.name ?? "Project"} />
      <main className="dash-main container">
        <Link href="/app" className="dash-back">
          ← Projects
        </Link>

        {loading && (
          <div className="dash-loading">
            <div className="spinner" role="status" aria-label="Loading project" />
          </div>
        )}
        {error && <p className="dash-error">{error}</p>}

        {!loading && project && !manageable && (
          <p className="dash-muted">Developer access required to manage this project.</p>
        )}

        {!loading && project && manageable && token && (
          <>
            <ProjectOverview
              project={project}
              role={role}
              openBugs={openBugs}
              onCopyInvite={copyInvite}
            />
            {copied && <p className="dash-muted dash-copy-ok">Invite link copied.</p>}

            <div className="dash-tabs-row">
              <div className="dash-tabs" role="tablist">
                {(
                  [
                    ["bugs", "Bugs"],
                    ["activity", "Activity"],
                    ["feedback", "Feedback"],
                  ] as const
                ).map(([value, label]) => (
                  <button
                    key={value}
                    type="button"
                    role="tab"
                    aria-selected={tab === value}
                    className={`dash-tab${tab === value ? " dash-tab--active" : ""}`}
                    onClick={() => setTab(value)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="dash-export">
                <button
                  type="button"
                  className="btn btn--ghost btn--sm"
                  onClick={() => handleExport("bugs")}
                >
                  Export bugs
                </button>
                <button
                  type="button"
                  className="btn btn--ghost btn--sm"
                  onClick={() => handleExport("feedback")}
                >
                  Export feedback
                </button>
              </div>
            </div>
            {exportError && <p className="dash-error">{exportError}</p>}

            {tab === "bugs" && (
              <BugBoard
                projectId={project.id}
                token={token}
                canManage={manageable}
                onOpenCountChange={onOpenCountChange}
              />
            )}
            {tab !== "bugs" && tabLoading && (
              <div className="dash-loading">
                <div className="spinner" role="status" aria-label="Loading" />
              </div>
            )}
            {tab === "activity" && !tabLoading && <ActivityPanel items={activity} />}
            {tab === "feedback" && !tabLoading && <FeedbackPanel items={feedback} />}
          </>
        )}
      </main>
    </RequireAuth>
  );
}
