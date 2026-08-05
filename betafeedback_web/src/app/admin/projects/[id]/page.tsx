"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { formatShort, formatWhen } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminProject } from "@/lib/admin-api";
import type { AdminProjectDetail } from "@/lib/admin-types";

export default function AdminProjectDetailPage() {
  const { token } = useAuth();
  const params = useParams<{ id: string }>();
  const [data, setData] = useState<AdminProjectDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token || !params.id) return;
    let cancelled = false;
    fetchAdminProject(token, params.id)
      .then((res) => {
        if (!cancelled) setData(res);
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Failed to load");
        }
      });
    return () => {
      cancelled = true;
    };
  }, [token, params.id]);

  return (
    <AdminShell>
      <Link className="admin-back" href="/admin/projects">
        ← Projects
      </Link>
      {error ? <div className="admin-error">{error}</div> : null}
      {!data && !error ? <div className="admin-loading">Loading…</div> : null}
      {data ? (
        <>
          <h1 className="admin-page-title">{data.project.name}</h1>
          <p className="admin-page-sub">
            {data.project.description || "No description"}
          </p>

          <div className="admin-kpis">
            <div className="admin-kpi">
              <div className="admin-kpi__label">Members</div>
              <div className="admin-kpi__value">{data.project.member_count}</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Testers</div>
              <div className="admin-kpi__value">{data.project.tester_count}</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Feedback</div>
              <div className="admin-kpi__value">{data.feedback_count}</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Bugs</div>
              <div className="admin-kpi__value">{data.bug_count}</div>
            </div>
          </div>

          <div className="admin-detail-grid">
            <div className="admin-panel">
              <div className="admin-panel__head">Meta</div>
              <dl className="admin-dl">
                <dt>Creator</dt>
                <dd>
                  <Link href={`/admin/users/${data.project.creator_id}`}>
                    {data.project.creator_name}
                  </Link>
                </dd>
                <dt>Invite code</dt>
                <dd className="admin-mono">{data.project.invite_code}</dd>
                <dt>Created</dt>
                <dd>{formatShort(data.project.created_at)}</dd>
              </dl>
            </div>
            <div className="admin-panel">
              <div className="admin-panel__head">Members</div>
              {!data.project.members?.length ? (
                <div className="admin-empty">No members.</div>
              ) : (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.project.members.map((m) => (
                        <tr key={m.user_id}>
                          <td>
                            <Link href={`/admin/users/${m.user_id}`}>
                              {m.name}
                            </Link>
                          </td>
                          <td className="admin-mono">{m.email}</td>
                          <td>
                            <span className="admin-badge">{m.role}</span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel__head">Recent feedback</div>
            {data.recent_feedback.length === 0 ? (
              <div className="admin-empty">No feedback yet.</div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>Author</th>
                      <th>Title / body</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_feedback.map((f) => (
                      <tr key={f.id}>
                        <td className="admin-mono">{formatWhen(f.created_at)}</td>
                        <td>
                          <Link href={`/admin/users/${f.author_id}`}>
                            {f.author_name}
                          </Link>
                        </td>
                        <td>
                          <div>{f.title || "Untitled"}</div>
                          <div className="admin-muted admin-clamp">{f.body}</div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div className="admin-panel">
            <div className="admin-panel__head">Recent activity</div>
            {data.recent_activity.length === 0 ? (
              <div className="admin-empty">No activity yet.</div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>Actor</th>
                      <th>Type</th>
                      <th>Subject</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_activity.map((a) => (
                      <tr key={a.id}>
                        <td className="admin-mono">{formatWhen(a.created_at)}</td>
                        <td>{a.actor_name}</td>
                        <td>
                          <span className="admin-badge">{a.type}</span>
                        </td>
                        <td>{a.subject}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      ) : null}
    </AdminShell>
  );
}
