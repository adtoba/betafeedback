"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Brand } from "@/components/Brand";
import { apiUrl } from "@/lib/api";
import type { InviteInfo } from "@/types/invite";

type ViewState = "loading" | "found" | "error";

export default function JoinPage() {
  const params = useParams<{ code: string }>();
  const code = decodeURIComponent(params.code ?? "");

  const [state, setState] = useState<ViewState>("loading");
  const [invite, setInvite] = useState<InviteInfo | null>(null);
  const [errorMsg, setErrorMsg] = useState(
    "The link may have expired or been mistyped. Ask whoever invited you for a fresh link.",
  );
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!code) {
      setState("error");
      return;
    }

    let cancelled = false;

    fetch(apiUrl(`/v1/invites/${encodeURIComponent(code)}`))
      .then((res) => {
        if (res.status === 404) throw new Error("not_found");
        if (!res.ok) throw new Error("server");
        return res.json() as Promise<InviteInfo>;
      })
      .then((data) => {
        if (cancelled) return;
        setInvite(data);
        setState("found");
      })
      .catch((err: Error) => {
        if (cancelled) return;
        if (err.message !== "not_found") {
          setErrorMsg("Something went wrong loading this invite. Please try again shortly.");
        }
        setState("error");
      });

    return () => {
      cancelled = true;
    };
  }, [code]);

  const copyCode = () => {
    navigator.clipboard?.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    });
  };

  const invitedBy =
    invite?.creator_name != null && invite.creator_name !== ""
      ? `${invite.creator_name} invited you to join the beta.`
      : "Join the beta and start sending feedback.";

  const testerMeta =
    invite && invite.tester_count > 0
      ? `${invite.tester_count} ${invite.tester_count === 1 ? "tester is" : "testers are"} already on board.`
      : null;

  return (
    <div className="join-wrap">
      <main className="join-card">
        <Brand />

        {state === "loading" && (
          <div>
            <div className="spinner" role="status" aria-label="Loading invite" />
            <p className="join-sub">Checking your invite…</p>
          </div>
        )}

        {state === "found" && invite && (
          <div>
            <h1>
              You’re invited to test{" "}
              <span className="grad">{invite.project_name || "this beta"}</span>
            </h1>
            <p className="join-sub">{invitedBy}</p>
            {testerMeta && <p className="join-meta">{testerMeta}</p>}

            <div className="code-box">
              <div>
                <div className="code-box__label">Invite code</div>
                <div className="code-box__value">{code}</div>
              </div>
              <button className="btn btn--ghost btn--sm" type="button" onClick={copyCode}>
                {copied ? "Copied" : "Copy"}
              </button>
            </div>

            <ol className="join-steps">
              <li>
                <span className="n">1</span>
                <span>
                  Get the <b>BetaFeedback</b> app on your device.
                </span>
              </li>
              <li>
                <span className="n">2</span>
                <span>Sign in with your email.</span>
              </li>
              <li>
                <span className="n">3</span>
                <span>Enter the invite code above to join the project.</span>
              </li>
            </ol>

            <div className="join-actions">
              <a
                className="btn btn--primary btn--lg"
                href="mailto:hello@betafeedback.com?subject=BetaFeedback%20app%20access"
              >
                Get the app
              </a>
            </div>
            <p className="join-foot">
              App Store &amp; Google Play links are coming soon — meanwhile we’ll get you set up.
            </p>
          </div>
        )}

        {state === "error" && (
          <div>
            <h1>This invite isn’t valid</h1>
            <p className="join-sub">{errorMsg}</p>
            <div className="join-actions">
              <Link className="btn btn--ghost btn--lg" href="/">
                Back to BetaFeedback
              </Link>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
