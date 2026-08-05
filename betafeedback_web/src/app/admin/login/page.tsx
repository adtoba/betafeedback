"use client";

import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useState } from "react";

import { GoogleSignInButton } from "@/components/dashboard/GoogleSignInButton";
import { useAuth } from "@/context/auth-context";
import { fetchAdminMe } from "@/lib/admin-api";
import { apiRequest, ApiError } from "@/lib/api-client";
import type { User } from "@/lib/types";

type Step = "email" | "code";

export default function AdminLoginPage() {
  const { ready, token, signIn, signOut } = useAuth();
  const router = useRouter();
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [debugCode, setDebugCode] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [googleReady, setGoogleReady] = useState(false);

  useEffect(() => {
    apiRequest<{ google_client_id?: string }>("/v1/auth/config")
      .then((cfg) => setGoogleReady(Boolean(cfg.google_client_id)))
      .catch(() => setGoogleReady(false));
  }, []);

  useEffect(() => {
    if (!ready || !token) return;
    let cancelled = false;
    fetchAdminMe(token)
      .then(() => {
        if (!cancelled) router.replace("/admin");
      })
      .catch((err) => {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 403) {
          setError("This account is not on the admin allowlist.");
          signOut();
          return;
        }
        if (err instanceof ApiError && err.status === 401) {
          signOut();
        }
      });
    return () => {
      cancelled = true;
    };
  }, [ready, token, router, signOut]);

  async function startEmail(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setDebugCode(null);
    try {
      const res = await apiRequest<{ expires_in: number; debug_code?: string }>(
        "/v1/auth/email/start",
        { method: "POST", body: { email } },
      );
      if (res.debug_code) setDebugCode(res.debug_code);
      setStep("code");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send code");
    } finally {
      setBusy(false);
    }
  }

  async function verifyCode(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const data = await apiRequest<{ token: string; user: User }>(
        "/v1/auth/email/verify",
        { method: "POST", body: { email, code } },
      );
      signIn(data.token, data.user);
      await fetchAdminMe(data.token);
      router.replace("/admin");
    } catch (err) {
      if (err instanceof ApiError && err.status === 403) {
        setError("This account is not on the admin allowlist.");
        signOut();
      } else {
        setError(err instanceof Error ? err.message : "Verification failed");
      }
    } finally {
      setBusy(false);
    }
  }

  async function afterGoogle() {
    // token is set synchronously via signIn inside the button; re-check allowlist
    const stored = localStorage.getItem("bf_token");
    if (!stored) return;
    try {
      await fetchAdminMe(stored);
      router.replace("/admin");
    } catch (err) {
      if (err instanceof ApiError && err.status === 403) {
        setError("This account is not on the admin allowlist.");
        signOut();
      } else {
        setError(err instanceof Error ? err.message : "Admin check failed");
      }
    }
  }

  return (
    <div className="admin-auth">
      <div className="admin-auth__card">
        <p className="admin-sidebar__eyebrow" style={{ marginBottom: 8 }}>
          Internal ops
        </p>
        <h1>Admin sign in</h1>
        <p>Sign in with an allowlisted account to view platform metrics.</p>

        {step === "email" ? (
          <form className="admin-auth__form" onSubmit={startEmail}>
            <label htmlFor="admin-email">Email</label>
            <input
              id="admin-email"
              className="admin-input"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
            />
            <button
              type="submit"
              className="admin-btn admin-btn--primary"
              disabled={busy}
            >
              {busy ? "Sending…" : "Send code"}
            </button>
          </form>
        ) : (
          <form className="admin-auth__form" onSubmit={verifyCode}>
            <label htmlFor="admin-code">Code sent to {email}</label>
            <input
              id="admin-code"
              className="admin-input"
              inputMode="numeric"
              autoComplete="one-time-code"
              required
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="6-digit code"
            />
            {debugCode ? (
              <p className="admin-muted admin-mono">Debug code: {debugCode}</p>
            ) : null}
            <button
              type="submit"
              className="admin-btn admin-btn--primary"
              disabled={busy}
            >
              {busy ? "Verifying…" : "Verify & enter"}
            </button>
            <button
              type="button"
              className="admin-btn admin-btn--ghost"
              onClick={() => {
                setStep("email");
                setCode("");
                setDebugCode(null);
              }}
            >
              Use a different email
            </button>
          </form>
        )}

        {googleReady ? (
          <>
            <div className="admin-auth__divider">or</div>
            <div className="admin-auth__google">
              <GoogleSignInButton
                onError={(message) => setError(message)}
                onDone={() => {
                  void afterGoogle();
                }}
              />
            </div>
          </>
        ) : null}

        {error ? <p className="admin-auth__error">{error}</p> : null}
      </div>
    </div>
  );
}
