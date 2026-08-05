"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { AdminPager, formatShort } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminUsers } from "@/lib/admin-api";
import type { AdminUserRow } from "@/lib/admin-types";

const PAGE = 50;

export default function AdminUsersPage() {
  const { token } = useAuth();
  const [q, setQ] = useState("");
  const [query, setQuery] = useState("");
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<AdminUserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAdminUsers({
        token,
        q: query,
        limit: PAGE,
        offset,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load users");
    } finally {
      setLoading(false);
    }
  }, [token, query, offset]);

  useEffect(() => {
    void load();
  }, [load]);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    setOffset(0);
    setQuery(q);
  }

  return (
    <AdminShell>
      <h1 className="admin-page-title">Users</h1>
      <p className="admin-page-sub">Search and browse all accounts.</p>

      <form className="admin-toolbar" onSubmit={onSearch}>
        <input
          className="admin-input"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search name or email"
        />
        <button type="submit" className="admin-btn admin-btn--primary">
          Search
        </button>
      </form>

      <div className="admin-panel">
        {error ? <div className="admin-error">{error}</div> : null}
        {loading ? <div className="admin-loading">Loading…</div> : null}
        {!loading && !error && items.length === 0 ? (
          <div className="admin-empty">No users found.</div>
        ) : null}
        {!loading && items.length > 0 ? (
          <>
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Plan</th>
                    <th>Projects</th>
                    <th>Joined</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((u) => (
                    <tr key={u.id}>
                      <td>
                        <Link href={`/admin/users/${u.id}`}>{u.name}</Link>
                      </td>
                      <td className="admin-mono">{u.email}</td>
                      <td>
                        <span
                          className={
                            u.plan === "pro"
                              ? "admin-badge admin-badge--pro"
                              : "admin-badge"
                          }
                        >
                          {u.plan}
                        </span>
                      </td>
                      <td>{u.project_count}</td>
                      <td className="admin-mono">{formatShort(u.created_at)}</td>
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
