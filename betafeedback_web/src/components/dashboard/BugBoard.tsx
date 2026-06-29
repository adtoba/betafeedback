"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { FixBugDialog } from "./FixBugDialog";
import { apiRequest } from "@/lib/api-client";
import { relativeTime, statusLabel } from "@/lib/project-utils";
import type { Release, StructuredBug } from "@/lib/types";

type BugFilter = "all" | "suggested" | "open" | "needs_info" | "fixed";
type BugSort = "newest" | "severity";
type BugViewMode = "checklist" | "cards";

const VIEW_KEY = "bug_summary_view_mode";
const severityOrder: Record<string, number> = {
  Critical: 0,
  High: 1,
  Medium: 2,
  Low: 3,
};

type BugBoardProps = {
  projectId: string;
  token: string;
  canManage: boolean;
  onOpenCountChange?: (count: number) => void;
};

export function BugBoard({ projectId, token, canManage, onOpenCountChange }: BugBoardProps) {
  const [bugs, setBugs] = useState<StructuredBug[]>([]);
  const [releases, setReleases] = useState<Release[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<BugFilter>("all");
  const [sort, setSort] = useState<BugSort>("newest");
  const [viewMode, setViewMode] = useState<BugViewMode>("checklist");
  const [selectedBug, setSelectedBug] = useState<StructuredBug | null>(null);
  const [fixTarget, setFixTarget] = useState<StructuredBug | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const loadBugs = useCallback(async () => {
    setError(null);
    try {
      const [bugsRes, releasesRes] = await Promise.all([
        apiRequest<{ bugs: StructuredBug[] }>(`/v1/projects/${projectId}/bugs`, { token }),
        apiRequest<{ releases: Release[] }>(`/v1/projects/${projectId}/releases`, { token }),
      ]);
      setBugs(bugsRes.bugs);
      setReleases(releasesRes.releases);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not load bugs");
    } finally {
      setLoading(false);
    }
  }, [projectId, token]);

  useEffect(() => {
    loadBugs();
  }, [loadBugs]);

  useEffect(() => {
    const stored = localStorage.getItem(VIEW_KEY);
    if (stored === "cards" || stored === "checklist") {
      setViewMode(stored);
    }
  }, []);

  useEffect(() => {
    if (!onOpenCountChange) return;
    const open = bugs.filter((b) => b.status === "open" || b.status === "suggested").length;
    onOpenCountChange(open);
  }, [bugs, onOpenCountChange]);

  function toggleViewMode() {
    const next = viewMode === "checklist" ? "cards" : "checklist";
    setViewMode(next);
    localStorage.setItem(VIEW_KEY, next);
  }

  async function runAction(fn: () => Promise<unknown>) {
    setActionError(null);
    try {
      await fn();
      await loadBugs();
      setSelectedBug(null);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Action failed");
    }
  }

  const counts = useMemo(
    () => ({
      suggested: bugs.filter((b) => b.status === "suggested").length,
      open: bugs.filter((b) => b.status === "open").length,
      needsInfo: bugs.filter((b) => b.status === "needs_info").length,
      fixed: bugs.filter((b) => b.status === "fixed").length,
    }),
    [bugs],
  );

  const visible = useMemo(() => {
    let list = bugs.filter((b) => {
      if (filter === "all") return true;
      if (filter === "needs_info") return b.status === "needs_info";
      return b.status === filter;
    });
    list = [...list];
    if (sort === "severity") {
      list.sort((a, b) => {
        const sa = severityOrder[a.severity] ?? 4;
        const sb = severityOrder[b.severity] ?? 4;
        if (sa !== sb) return sa - sb;
        return new Date(b.structured_at).getTime() - new Date(a.structured_at).getTime();
      });
    } else {
      list.sort(
        (a, b) =>
          new Date(b.structured_at).getTime() - new Date(a.structured_at).getTime(),
      );
    }
    return list;
  }, [bugs, filter, sort]);

  if (loading) {
    return (
      <div className="dash-loading">
        <div className="spinner" role="status" aria-label="Loading bugs" />
      </div>
    );
  }

  if (error) {
    return <p className="dash-error">{error}</p>;
  }

  if (bugs.length === 0) {
    return (
      <div className="dash-empty">
        <h2>No structured bugs yet</h2>
        <p>When testers submit feedback, AI drafts land here for you to confirm and track.</p>
      </div>
    );
  }

  return (
    <>
      <div className="dash-stats">
        <Stat value={counts.suggested} label="Suggested" tone="tertiary" />
        <Stat value={counts.open} label="Open" tone="error" />
        <Stat value={counts.needsInfo} label="Needs info" tone="secondary" />
        <Stat value={counts.fixed} label="Fixed" tone="primary" />
      </div>

      <div className="dash-toolbar">
        <div className="dash-chips">
          {(
            [
              ["all", "All"],
              ["suggested", "Suggested"],
              ["open", "Open"],
              ["needs_info", "Needs info"],
              ["fixed", "Fixed"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={`dash-chip${filter === value ? " dash-chip--active" : ""}`}
              onClick={() => setFilter(value)}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="dash-toolbar__right">
          <select
            className="dash-select"
            value={sort}
            onChange={(e) => setSort(e.target.value as BugSort)}
            aria-label="Sort bugs"
          >
            <option value="newest">Newest first</option>
            <option value="severity">By severity</option>
          </select>
          <button type="button" className="btn btn--ghost btn--sm" onClick={toggleViewMode}>
            {viewMode === "checklist" ? "Detailed cards" : "Checklist"}
          </button>
        </div>
      </div>

      {actionError && <p className="dash-error">{actionError}</p>}

      {visible.length === 0 ? (
        <p className="dash-muted">No bugs match this filter.</p>
      ) : viewMode === "checklist" ? (
        <div className="dash-checklist card">
          {visible.map((bug, index) => (
            <div key={bug.id}>
              {index > 0 && <hr className="dash-divider" />}
              <BugChecklistRow
                bug={bug}
                canManage={canManage}
                onOpen={() => setSelectedBug(bug)}
                onConfirm={() =>
                  runAction(() =>
                    apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/confirm`, {
                      method: "POST",
                      token,
                    }),
                  )
                }
                onMarkFixed={() => setFixTarget(bug)}
                onReopen={() =>
                  runAction(() =>
                    apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/reopen`, {
                      method: "POST",
                      token,
                    }),
                  )
                }
              />
            </div>
          ))}
        </div>
      ) : (
        <div className="dash-cards">
          {visible.map((bug) => (
            <BugCard
              key={bug.id}
              bug={bug}
              canManage={canManage}
              onConfirm={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/confirm`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onDismiss={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/dismiss`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onMarkFixed={() => setFixTarget(bug)}
              onNeedsInfo={async () => {
                const note = window.prompt("What do you need from the tester?");
                if (note === null) return;
                await runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/needs-info`, {
                    method: "POST",
                    token,
                    body: note.trim() ? { note: note.trim() } : {},
                  }),
                );
              }}
              onResume={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/resume`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onReopen={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${bug.id}/reopen`, {
                    method: "POST",
                    token,
                  }),
                )
              }
            />
          ))}
        </div>
      )}

      {selectedBug && (
        <div className="dash-modal-backdrop" onClick={() => setSelectedBug(null)} role="presentation">
          <div className="dash-modal dash-modal--wide" onClick={(e) => e.stopPropagation()} role="dialog">
            <BugCard
              bug={selectedBug}
              canManage={canManage}
              expanded
              onConfirm={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${selectedBug.id}/confirm`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onDismiss={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${selectedBug.id}/dismiss`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onMarkFixed={() => setFixTarget(selectedBug)}
              onNeedsInfo={async () => {
                const note = window.prompt("What do you need from the tester?");
                if (note === null) return;
                await runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${selectedBug.id}/needs-info`, {
                    method: "POST",
                    token,
                    body: note.trim() ? { note: note.trim() } : {},
                  }),
                );
              }}
              onResume={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${selectedBug.id}/resume`, {
                    method: "POST",
                    token,
                  }),
                )
              }
              onReopen={() =>
                runAction(() =>
                  apiRequest(`/v1/projects/${projectId}/bugs/${selectedBug.id}/reopen`, {
                    method: "POST",
                    token,
                  }),
                )
              }
            />
            <button type="button" className="btn btn--ghost" onClick={() => setSelectedBug(null)}>
              Close
            </button>
          </div>
        </div>
      )}

      <FixBugDialog
        projectId={projectId}
        bugId={fixTarget?.id ?? ""}
        bugTitle={fixTarget?.title ?? ""}
        releases={releases}
        token={token}
        open={fixTarget !== null}
        onClose={() => setFixTarget(null)}
        onFixed={loadBugs}
      />
    </>
  );
}

function Stat({
  value,
  label,
  tone,
}: {
  value: number;
  label: string;
  tone: "primary" | "secondary" | "tertiary" | "error";
}) {
  return (
    <div className={`dash-stat dash-stat--${tone}`}>
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function BugChecklistRow({
  bug,
  canManage,
  onOpen,
  onConfirm,
  onMarkFixed,
  onReopen,
}: {
  bug: StructuredBug;
  canManage: boolean;
  onOpen: () => void;
  onConfirm: () => void;
  onMarkFixed: () => void;
  onReopen: () => void;
}) {
  const isFixed = bug.status === "fixed";
  const canToggle =
    canManage &&
    (bug.status === "suggested" || bug.status === "open" || bug.status === "fixed");

  function onCheckChange(e: React.ChangeEvent<HTMLInputElement>) {
    const checked = e.target.checked;
    if (checked) {
      if (bug.status === "suggested") onConfirm();
      else if (bug.status === "open") onMarkFixed();
      return;
    }
    if (!checked && bug.status === "fixed") onReopen();
  }

  return (
    <div className="dash-checklist__row">
      <input
        type="checkbox"
        className="dash-checklist__box"
        checked={isFixed}
        disabled={!canToggle}
        onChange={onCheckChange}
        aria-label={isFixed ? "Reopen bug" : "Mark bug fixed"}
      />
      <button type="button" className="dash-checklist__body" onClick={onOpen}>
        <span
          className={`dash-checklist__title${isFixed ? " dash-checklist__title--fixed" : ""}`}
        >
          {bug.title}
        </span>
        <span className="dash-checklist__sub">
          <span className={`dash-status dash-status--${bug.status}`}>
            {statusLabel(bug.status)}
          </span>
          <span className={`dash-severity dash-severity--${bug.severity.toLowerCase()}`}>
            {bug.severity}
          </span>
        </span>
      </button>
    </div>
  );
}

function BugCard({
  bug,
  canManage,
  expanded = false,
  onConfirm,
  onDismiss,
  onMarkFixed,
  onNeedsInfo,
  onResume,
  onReopen,
}: {
  bug: StructuredBug;
  canManage: boolean;
  expanded?: boolean;
  onConfirm: () => void;
  onDismiss: () => void;
  onMarkFixed: () => void;
  onNeedsInfo: () => void;
  onResume: () => void;
  onReopen: () => void;
}) {
  const isFixed = bug.status === "fixed";
  const isSuggested = bug.status === "suggested";
  const isOpen = bug.status === "open";
  const isNeedsInfo = bug.status === "needs_info";

  return (
    <article className={`dash-bug card${expanded ? " dash-bug--expanded" : ""}`}>
      <div className="dash-bug__head">
        <span className={`dash-status dash-status--${bug.status}`}>{statusLabel(bug.status)}</span>
        <span className={`dash-severity dash-severity--${bug.severity.toLowerCase()}`}>
          {bug.severity}
        </span>
      </div>
      <h3 className={isFixed ? "dash-bug__title dash-bug__title--fixed" : "dash-bug__title"}>
        {bug.title}
      </h3>
      {bug.reporter_name && <p className="dash-muted">Reported by {bug.reporter_name}</p>}
      <div className="dash-bug__sections">
        {bug.steps.length > 0 && (
          <section>
            <h4>Steps to reproduce</h4>
            <ol>
              {bug.steps.map((step, i) => (
                <li key={i}>{step}</li>
              ))}
            </ol>
          </section>
        )}
        {bug.expected && (
          <section>
            <h4>Expected</h4>
            <p>{bug.expected}</p>
          </section>
        )}
        {bug.actual && (
          <section>
            <h4>Actual</h4>
            <p>{bug.actual}</p>
          </section>
        )}
      </div>
      {isFixed && (
        <p className="dash-bug__fixed">
          Fixed {bug.fixed_in_release_version ? `in ${bug.fixed_in_release_version}` : ""}
          {bug.fixed_at ? ` · ${relativeTime(bug.fixed_at)}` : ""}
        </p>
      )}
      {bug.fix_note && <p className="dash-muted">{bug.fix_note}</p>}
      {canManage && (
        <div className="dash-bug__actions">
          {isSuggested && (
            <>
              <button type="button" className="btn btn--ghost btn--sm" onClick={onDismiss}>
                Dismiss
              </button>
              <button type="button" className="btn btn--primary btn--sm" onClick={onConfirm}>
                Confirm bug
              </button>
            </>
          )}
          {isOpen && (
            <>
              <button type="button" className="btn btn--ghost btn--sm" onClick={onNeedsInfo}>
                Request info
              </button>
              <button type="button" className="btn btn--primary btn--sm" onClick={onMarkFixed}>
                Mark fixed
              </button>
            </>
          )}
          {isNeedsInfo && (
            <button type="button" className="btn btn--primary btn--sm" onClick={onResume}>
              Back to open
            </button>
          )}
          {isFixed && (
            <button type="button" className="btn btn--ghost btn--sm" onClick={onReopen}>
              Reopen
            </button>
          )}
        </div>
      )}
    </article>
  );
}
