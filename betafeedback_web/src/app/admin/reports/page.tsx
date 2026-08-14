"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { AdminPager, formatWhen } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminReports } from "@/lib/admin-api";
import type { AdminUserReport } from "@/lib/admin-types";

const PAGE = 50;

export default function AdminReportsPage() {
  const { token } = useAuth();
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<AdminUserReport[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAdminReports({
        token,
        limit: PAGE,
        offset,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load reports");
    } finally {
      setLoading(false);
    }
  }, [token, offset]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <AdminShell>
      <h1 className="admin-page-title">Reports</h1>
      <p className="admin-page-sub">
        User-submitted safety reports. Act within 24 hours.
      </p>

      <div className="admin-panel">
        {error ? <div className="admin-error">{error}</div> : null}
        {loading ? <div className="admin-loading">Loading…</div> : null}
        {!loading && !error && items.length === 0 ? (
          <div className="admin-empty">No reports yet.</div>
        ) : null}
        {!loading && items.length > 0 ? (
          <>
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Reporter</th>
                    <th>Reported</th>
                    <th>Reason</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((r) => (
                    <tr key={r.id}>
                      <td className="admin-mono">{formatWhen(r.created_at)}</td>
                      <td>
                        <Link href={`/admin/users/${r.reporter_id}`}>
                          {r.reporter_name}
                        </Link>
                        <div className="admin-muted">{r.reporter_email}</div>
                      </td>
                      <td>
                        <Link href={`/admin/users/${r.reported_user_id}`}>
                          {r.reported_name}
                        </Link>
                        <div className="admin-muted">{r.reported_email}</div>
                      </td>
                      <td>{r.reason}</td>
                      <td>
                        <div className="admin-muted admin-clamp">
                          {r.details || "—"}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <AdminPager
              total={total}
              limit={PAGE}
              offset={offset}
              onPrev={() => setOffset((o) => Math.max(0, o - PAGE))}
              onNext={() => setOffset((o) => o + PAGE)}
            />
          </>
        ) : null}
      </div>
    </AdminShell>
  );
}
