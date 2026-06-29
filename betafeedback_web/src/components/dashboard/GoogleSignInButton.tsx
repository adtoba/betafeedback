"use client";

import { GoogleLogin } from "@react-oauth/google";

import { apiRequest } from "@/lib/api-client";
import { useAuth } from "@/context/auth-context";
import type { User } from "@/lib/types";

type GoogleSignInButtonProps = {
  onError: (message: string) => void;
  onDone: () => void;
};

export function GoogleSignInButton({ onError, onDone }: GoogleSignInButtonProps) {
  const { signIn } = useAuth();

  return (
    <GoogleLogin
      text="continue_with"
      shape="rectangular"
      theme="outline"
      size="large"
      width={320}
      onSuccess={async (res) => {
        if (!res.credential) return;
        try {
          const data = await apiRequest<{ token: string; user: User }>("/v1/auth/google", {
            method: "POST",
            body: { id_token: res.credential },
          });
          signIn(data.token, data.user);
          onDone();
        } catch (err) {
          onError(err instanceof Error ? err.message : "Google sign-in failed");
        }
      }}
      onError={() => onError("Google sign-in was cancelled")}
    />
  );
}
