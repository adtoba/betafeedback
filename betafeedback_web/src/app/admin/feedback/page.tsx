"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useState } from "react";

import { AdminShell } from "@/components/admin/AdminShell";
import { AdminPager, formatWhen } from "@/components/admin/admin-utils";
import { useAuth } from "@/context/auth-context";
import { fetchAdminFeedback } from "@/lib/admin-api";
import type { AdminFeedbackRow } from "@/lib/admin-types";

const PAGE = 50;

export default function AdminFeedbackPage() {
  const { token } = useAuth();
  const [q, setQ] = useState("");
  const [query, setQuery] = useState("");
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<AdminFeedbackRow[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAdminFeedback({
        token,
        q: query,
        limit: PAGE,
        offset,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load feedback");
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
      <h1 className="admin-page-title">Feedback</h1>
      <p className="admin-page-sub">Cross-project feedback feed.</p>

      <form className="admin-toolbar" onSubmit={onSearch}>
        <input
          className="admin-input"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search title, body, project, author"
        />
        <button type="submit" className="admin-btn admin-btn--primary">
          Search
        </button>
      </form>

      <div className="admin-panel">
        {error ? <div className="admin-error">{error}</div> : null}
        {loading ? <div className="admin-loading">Loading…</div> : null}
        {!loading && !error && items.length === 0 ? (
          <div className="admin-empty">No feedback found.</div>
        ) : null}
        {!loading && items.length > 0 ? (
          <>
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Project</th>
                    <th>Author</th>
                    <th>Content</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((f) => (
                    <tr key={f.id}>
                      <td className="admin-mono">{formatWhen(f.created_at)}</td>
                      <td>
                        <Link href={`/admin/projects/${f.project_id}`}>
                          {f.project_name}
                        </Link>
                      </td>
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
