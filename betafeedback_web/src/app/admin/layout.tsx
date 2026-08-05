"use client";

import { GoogleOAuthProvider } from "@react-oauth/google";
import { useEffect, useState, type ReactNode } from "react";

import { AuthProvider } from "@/context/auth-context";
import { apiRequest } from "@/lib/api-client";

import "./admin.css";

export default function AdminLayout({ children }: { children: ReactNode }) {
  const [googleClientId, setGoogleClientId] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiRequest<{ google_client_id?: string }>("/v1/auth/config")
      .then((cfg) => {
        if (!cancelled && cfg.google_client_id) {
          setGoogleClientId(cfg.google_client_id);
        }
      })
      .catch(() => {
        /* Google optional */
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const body = <AuthProvider>{children}</AuthProvider>;

  return (
    <div className="admin-root">
      {googleClientId ? (
        <GoogleOAuthProvider clientId={googleClientId}>{body}</GoogleOAuthProvider>
      ) : (
        body
      )}
    </div>
  );
}
