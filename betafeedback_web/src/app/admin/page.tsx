"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { formatWhen } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminOverview } from "@/lib/admin-api";
import type { AdminOverview } from "@/lib/admin-types";

export default function AdminOverviewPage() {
  const { token } = useAuth();
  const [data, setData] = useState<AdminOverview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;
    fetchAdminOverview(token)
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
  }, [token]);

  return (
    <AdminShell>
      <h1 className="admin-page-title">Overview</h1>
      <p className="admin-page-sub">Platform-wide snapshot for ops.</p>

      {error ? <div className="admin-error">{error}</div> : null}
      {!data && !error ? <div className="admin-loading">Loading…</div> : null}

      {data ? (
        <>
          <div className="admin-kpis">
            <div className="admin-kpi">
              <div className="admin-kpi__label">Users</div>
              <div className="admin-kpi__value">{data.users_total}</div>
              <div className="admin-kpi__hint">
                +{data.users_last_7_days} / 7d · +{data.users_last_30_days} / 30d
              </div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Projects</div>
              <div className="admin-kpi__value">{data.projects_total}</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Feedback</div>
              <div className="admin-kpi__value">{data.feedback_total}</div>
              <div className="admin-kpi__hint">
                +{data.feedback_last_7_days} / 7d · +{data.feedback_last_30_days}{" "}
                / 30d
              </div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Bugs</div>
              <div className="admin-kpi__value">{data.bugs_total}</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Pro</div>
              <div className="admin-kpi__value">{data.subs_pro}</div>
              <div className="admin-kpi__hint">{data.subs_free} free</div>
            </div>
            <div className="admin-kpi">
              <div className="admin-kpi__label">Swaps pending</div>
              <div className="admin-kpi__value">{data.swaps_pending}</div>
              <div className="admin-kpi__hint">
                {data.swaps_fulfilled} fulfilled · {data.swaps_accepted} accepted
              </div>
            </div>
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
                      <th>Project</th>
                      <th>Actor</th>
                      <th>Type</th>
                      <th>Subject</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_activity.map((a) => (
                      <tr key={a.id}>
                        <td className="admin-mono">{formatWhen(a.created_at)}</td>
                        <td>
                          <Link href={`/admin/projects/${a.project_id}`}>
                            {a.project_name}
                          </Link>
                        </td>
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
