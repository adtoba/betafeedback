"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import {
  AdminPager,
  formatWhen,
  swapStatusBadge,
} from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminSwaps } from "@/lib/admin-api";
import type { AdminTestSwap } from "@/lib/admin-types";

const PAGE = 50;
const STATUSES = ["", "pending", "accepted", "fulfilled", "declined", "cancelled"];

export default function AdminSwapsPage() {
  const { token } = useAuth();
  const [status, setStatus] = useState("");
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<AdminTestSwap[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAdminSwaps({
        token,
        status,
        limit: PAGE,
        offset,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load swaps");
    } finally {
      setLoading(false);
    }
  }, [token, status, offset]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <AdminShell>
      <h1 className="admin-page-title">Swaps</h1>
      <p className="admin-page-sub">Test-for-test swap pipeline.</p>

      <div className="admin-toolbar">
        <select
          className="admin-select"
          value={status}
          onChange={(e) => {
            setOffset(0);
            setStatus(e.target.value);
          }}
        >
          {STATUSES.map((s) => (
            <option key={s || "all"} value={s}>
              {s ? s : "All statuses"}
            </option>
          ))}
        </select>
      </div>

      <div className="admin-panel">
        {error ? <div className="admin-error">{error}</div> : null}
        {loading ? <div className="admin-loading">Loading…</div> : null}
        {!loading && !error && items.length === 0 ? (
          <div className="admin-empty">No swaps found.</div>
        ) : null}
        {!loading && items.length > 0 ? (
          <>
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>When</th>
                    <th>From</th>
                    <th>To</th>
                    <th>Projects</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((s) => (
                    <tr key={s.id}>
                      <td className="admin-mono">{formatWhen(s.created_at)}</td>
                      <td>
                        <Link href={`/admin/users/${s.from_user_id}`}>
                          {s.from_user_name}
                        </Link>
                      </td>
                      <td>
                        <Link href={`/admin/users/${s.to_user_id}`}>
                          {s.to_user_name}
                        </Link>
                      </td>
                      <td>
                        <Link href={`/admin/projects/${s.from_project_id}`}>
                          {s.from_project_name}
                        </Link>
                        {" ↔ "}
                        <Link href={`/admin/projects/${s.to_project_id}`}>
                          {s.to_project_name}
                        </Link>
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
