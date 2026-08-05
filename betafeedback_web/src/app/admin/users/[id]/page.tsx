"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import {
  formatShort,
  formatWhen,
  swapStatusBadge,
} from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminUser } from "@/lib/admin-api";
import type { AdminUserDetail } from "@/lib/admin-types";

export default function AdminUserDetailPage() {
  const { token } = useAuth();
  const params = useParams<{ id: string }>();
  const [data, setData] = useState<AdminUserDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token || !params.id) return;
    let cancelled = false;
    fetchAdminUser(token, params.id)
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
      <Link className="admin-back" href="/admin/users">
        ← Users
      </Link>
      {error ? <div className="admin-error">{error}</div> : null}
      {!data && !error ? <div className="admin-loading">Loading…</div> : null}
      {data ? (
        <>
          <h1 className="admin-page-title">{data.user.name}</h1>
          <p className="admin-page-sub admin-mono">{data.user.email}</p>

          <div className="admin-detail-grid">
            <div className="admin-panel">
              <div className="admin-panel__head">Profile</div>
              <dl className="admin-dl">
                <dt>Joined</dt>
                <dd>{formatShort(data.user.created_at)}</dd>
                <dt>Open to test</dt>
                <dd>{data.user.open_to_test ? "Yes" : "No"}</dd>
                <dt>Open to swap</dt>
                <dd>{data.user.open_to_swap ? "Yes" : "No"}</dd>
                <dt>Bio</dt>
                <dd>{data.user.tester_bio || "—"}</dd>
              </dl>
            </div>
            <div className="admin-panel">
              <div className="admin-panel__head">Subscription</div>
              <dl className="admin-dl">
                <dt>Plan</dt>
                <dd>
                  <span
                    className={
                      data.subscription.plan === "pro"
                        ? "admin-badge admin-badge--pro"
                        : "admin-badge"
                    }
                  >
                    {data.subscription.plan}
                  </span>
                </dd>
                <dt>Status</dt>
                <dd>{data.subscription.status}</dd>
                <dt>Renews</dt>
                <dd>{data.subscription.renews_on || "—"}</dd>
                <dt>Projects created</dt>
                <dd>
                  {data.subscription.projects_created}
                  {data.subscription.project_limit != null
                    ? ` / ${data.subscription.project_limit}`
                    : ""}
                </dd>
              </dl>
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel__head">Projects</div>
            {data.projects.length === 0 ? (
              <div className="admin-empty">No project memberships.</div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Project</th>
                      <th>Role</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.projects.map((p) => (
                      <tr key={p.id}>
                        <td>
                          <Link href={`/admin/projects/${p.id}`}>{p.name}</Link>
                        </td>
                        <td>
                          <span className="admin-badge">{p.role}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div className="admin-panel">
            <div className="admin-panel__head">Recent feedback</div>
            {data.recent_feedback.length === 0 ? (
              <div className="admin-empty">No feedback authored.</div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>Project</th>
                      <th>Title / body</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_feedback.map((f) => (
                      <tr key={f.id}>
                        <td className="admin-mono">{formatWhen(f.created_at)}</td>
                        <td>
                          <Link href={`/admin/projects/${f.project_id}`}>
                            {f.project_name}
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
            <div className="admin-panel__head">Recent swaps</div>
            {data.recent_swaps.length === 0 ? (
              <div className="admin-empty">No swaps.</div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>From → To</th>
                      <th>Projects</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_swaps.map((s) => (
                      <tr key={s.id}>
                        <td className="admin-mono">{formatWhen(s.created_at)}</td>
                        <td>
                          {s.from_user_name} → {s.to_user_name}
                        </td>
                        <td>
                          {s.from_project_name} ↔ {s.to_project_name}
                        </td>
                        <td>
                          <span className={swapStatusBadge(s.status)}>
                            {s.status}
                          </span>
                        </td>
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
