"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";

import { useAuth } from "@/context/auth-context";
import { fetchAdminMe } from "@/lib/admin-api";
import { ApiError } from "@/lib/api-client";

const NAV: Array<{ href: string; label: string; exact?: boolean }> = [
  { href: "/admin", label: "Overview", exact: true },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/projects", label: "Projects" },
  { href: "/admin/feedback", label: "Feedback" },
  { href: "/admin/swaps", label: "Swaps" },
];

export function AdminShell({ children }: { children: ReactNode }) {
  const { ready, token, user, signOut } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [checking, setChecking] = useState(true);
  const [denied, setDenied] = useState(false);

  useEffect(() => {
    if (!ready) return;
    if (!token) {
      router.replace("/admin/login");
      return;
    }

    let cancelled = false;
    setChecking(true);
    setDenied(false);
    fetchAdminMe(token)
      .then(() => {
        if (!cancelled) setChecking(false);
      })
      .catch((err) => {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 403) {
          setDenied(true);
          setChecking(false);
          return;
        }
        if (err instanceof ApiError && err.status === 401) {
          signOut();
          router.replace("/admin/login");
          return;
        }
        setChecking(false);
      });

    return () => {
      cancelled = true;
    };
  }, [ready, token, router, signOut]);

  if (!ready || checking) {
    return <div className="admin-loading">Checking admin access…</div>;
  }

  if (denied) {
    return (
      <div className="admin-auth">
        <div className="admin-auth__card">
          <h1>Not an admin</h1>
          <p>
            Signed in as {user?.email}, but this account is not on the admin
            allowlist.
          </p>
          <button
            type="button"
            className="admin-btn admin-btn--primary"
            onClick={() => {
              signOut();
              router.replace("/admin/login");
            }}
          >
            Sign out
          </button>
        </div>
      </div>
    );
  }

  if (!token) return null;

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <Link href="/admin" className="admin-sidebar__brand">
          <Image src="/brand/app-icon.png" alt="" width={32} height={32} />
          <span>
            <span className="admin-sidebar__eyebrow">Ops</span>
            <div className="admin-sidebar__title">Admin</div>
          </span>
        </Link>
        <nav className="admin-nav" aria-label="Admin">
          {NAV.map((item) => {
            const active = item.exact
              ? pathname === item.href
              : pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="admin-sidebar__foot">
          <div className="admin-sidebar__user">{user?.email}</div>
          <button
            type="button"
            className="admin-btn admin-btn--ghost"
            onClick={() => {
              signOut();
              router.replace("/admin/login");
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="admin-main">{children}</main>
    </div>
  );
}
