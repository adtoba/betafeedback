"use client";

import Link from "next/link";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { GoogleSignInButton } from "@/components/dashboard/GoogleSignInButton";
import { apiRequest } from "@/lib/api-client";
import { useAuth } from "@/context/auth-context";
import type { AuthConfig, User } from "@/lib/types";

function GoogleGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="#4285F4"
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
      />
      <path
        fill="#FBBC05"
        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
      />
      <path
        fill="#EA4335"
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
      />
    </svg>
  );
}

export default function LoginPage() {
  const { signIn, token, ready } = useAuth();
  const router = useRouter();

  const [step, setStep] = useState<"start" | "code">("start");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [debugCode, setDebugCode] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [googleClientId, setGoogleClientId] = useState<string | null>(null);

  useEffect(() => {
    apiRequest<AuthConfig>("/v1/auth/config")
      .then((cfg) => setGoogleClientId(cfg.google_client_id ?? ""))
      .catch(() => setGoogleClientId(""));
  }, []);

  if (ready && token) {
    router.replace("/app");
    return null;
  }

  async function requestCode() {
    const res = await apiRequest<{ debug_code?: string }>("/v1/auth/email/start", {
      method: "POST",
      body: { email: email.trim() },
    });
    setDebugCode(res.debug_code ?? null);
  }

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await requestCode();
      setStep("code");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send code");
    } finally {
      setLoading(false);
    }
  }

  async function resendCode() {
    setError(null);
    setResending(true);
    try {
      await requestCode();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not resend code");
    } finally {
      setResending(false);
    }
  }

  async function verifyCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await apiRequest<{ token: string; user: User }>("/v1/auth/email/verify", {
        method: "POST",
        body: { email: email.trim(), code: code.trim() },
      });
      signIn(res.token, res.user);
      router.replace("/app");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invalid code");
    } finally {
      setLoading(false);
    }
  }

  const googleReady = googleClientId !== null && googleClientId.length > 0;

  const googleSection =
    googleClientId === null ? (
      <div className="dash-auth__google-placeholder" aria-hidden="true" />
    ) : googleReady ? (
      <GoogleOAuthProvider clientId={googleClientId}>
        <GoogleSignInButton onError={setError} onDone={() => router.replace("/app")} />
      </GoogleOAuthProvider>
    ) : (
      <button type="button" className="dash-social-btn" disabled>
        <GoogleGlyph />
        Continue with Google
      </button>
    );

  return (
    <div className="dash-auth">
      <div className="dash-auth__glow" aria-hidden="true" />
      <div className="dash-auth__inner">
        <div className="dash-auth__card">
          <div className="brand dash-auth__brand">
            <span className="brand__mark" aria-hidden="true">
              β
            </span>
            <span className="brand__name">BetaFeedback</span>
          </div>

          {step === "start" ? (
            <>
              <div className="dash-auth__head">
                <h1 className="dash-auth__title">Developer sign in</h1>
                <p className="dash-auth__sub">
                  Track bugs, releases, and tester feedback for your projects.
                </p>
              </div>

              <div className="dash-auth__google">{googleSection}</div>
              {googleClientId !== null && !googleReady && (
                <p className="dash-auth__setup">
                  Add <code>GOOGLE_CLIENT_ID</code> to the backend <code>.env</code> to enable
                  Google sign-in.
                </p>
              )}

              <div className="dash-or">or</div>

              <form onSubmit={sendCode} className="dash-form">
                <div className="dash-field">
                  <label className="dash-label" htmlFor="auth-email">
                    Email address
                  </label>
                  <input
                    id="auth-email"
                    className="dash-input"
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@company.com"
                  />
                </div>
                <button className="btn btn--primary" type="submit" disabled={loading}>
                  {loading ? "Sending…" : "Continue with email"}
                </button>
              </form>
            </>
          ) : (
            <>
              <div className="dash-auth__head">
                <h1 className="dash-auth__title">Check your email</h1>
                <p className="dash-auth__sub">
                  We sent a 6-digit code to <b>{email}</b>.
                </p>
              </div>

              <form onSubmit={verifyCode} className="dash-form">
                {debugCode && (
                  <p className="dash-auth__codebox">
                    Dev mode code: <b>{debugCode}</b>
                  </p>
                )}
                <div className="dash-field">
                  <label className="dash-label" htmlFor="auth-code">
                    Verification code
                  </label>
                  <input
                    id="auth-code"
                    className="dash-input dash-input--code"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    required
                    maxLength={6}
                    value={code}
                    onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                    placeholder="••••••"
                    autoFocus
                  />
                </div>
                <button className="btn btn--primary" type="submit" disabled={loading}>
                  {loading ? "Verifying…" : "Verify & continue"}
                </button>
              </form>

              <div className="dash-auth__alt">
                <button
                  type="button"
                  className="dash-linkbtn"
                  onClick={resendCode}
                  disabled={resending}
                >
                  {resending ? "Resending…" : "Resend code"}
                </button>
                <span>·</span>
                <button
                  type="button"
                  className="dash-linkbtn"
                  onClick={() => {
                    setStep("start");
                    setCode("");
                    setDebugCode(null);
                    setError(null);
                  }}
                >
                  Use a different email
                </button>
              </div>
            </>
          )}

          {error && <p className="dash-error">{error}</p>}
        </div>

        <Link href="/" className="dash-auth__foot">
          ← Back to home
        </Link>
      </div>
    </div>
  );
}
