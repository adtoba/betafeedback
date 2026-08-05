"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { AdminPager, formatShort } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminProjects } from "@/lib/admin-api";
import type { AdminProjectRow } from "@/lib/admin-types";

const PAGE = 50;

export default function AdminProjectsPage() {
  const { token } = useAuth();
  const [q, setQ] = useState("");
  const [query, setQuery] = useState("");
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<AdminProjectRow[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAdminProjects({
        token,
        q: query,
        limit: PAGE,
        offset,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load projects");
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
      <h1 className="admin-page-title">Projects</h1>
      <p className="admin-page-sub">All projects across the platform.</p>

      <form className="admin-toolbar" onSubmit={onSearch}>
        <input
          className="admin-input"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search by name"
        />
        <button type="submit" className="admin-btn admin-btn--primary">
          Search
        </button>
      </form>

      <div className="admin-panel">
        {error ? <div className="admin-error">{error}</div> : null}
        {loading ? <div className="admin-loading">Loading…</div> : null}
        {!loading && !error && items.length === 0 ? (
          <div className="admin-empty">No projects found.</div>
        ) : null}
        {!loading && items.length > 0 ? (
          <>
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Creator</th>
                    <th>Members</th>
                    <th>Testers</th>
                    <th>Feedback</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((p) => (
                    <tr key={p.id}>
                      <td>
                        <Link href={`/admin/projects/${p.id}`}>{p.name}</Link>
                      </td>
                      <td>
                        <Link href={`/admin/users/${p.creator_id}`}>
                          {p.creator_name}
                        </Link>
                        <div className="admin-muted admin-mono">
                          {p.creator_email}
                        </div>
                      </td>
                      <td>{p.member_count}</td>
                      <td>{p.tester_count}</td>
                      <td>{p.feedback_count}</td>
                      <td className="admin-mono">{formatShort(p.created_at)}</td>
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
