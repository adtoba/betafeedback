"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { initials } from "@/lib/project-utils";
import { useAuth } from "@/context/auth-context";

export function DashboardHeader({ title }: { title?: string }) {
  const { user, signOut } = useAuth();
  const router = useRouter();

  return (
    <header className="dash-header">
      <Link href="/app" className="brand">
        <span className="brand__mark" aria-hidden="true">
          β
        </span>
        <span className="brand__name">BetaFeedback</span>
      </Link>
      {title && <span className="dash-header__title">{title}</span>}
      <div className="dash-header__right">
        {user && (
          <span className="dash-user" title={user.email}>
            <span
              className="dash-avatar"
              style={{ "--hue": user.avatar_hue } as React.CSSProperties}
              aria-hidden="true"
            >
              {initials(user.name)}
            </span>
            <span className="dash-user__name">{user.name}</span>
          </span>
        )}
        <button
          type="button"
          className="dash-link-btn"
          onClick={() => {
            signOut();
            router.replace("/app/login");
          }}
        >
          Sign out
        </button>
      </div>
    </header>
  );
}

export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { token, ready } = useAuth();
  const router = useRouter();

  if (!ready) {
    return (
      <div className="dash-loading">
        <div className="spinner" role="status" aria-label="Loading" />
      </div>
    );
  }

  if (!token) {
    router.replace("/app/login");
    return null;
  }

  return children;
}
