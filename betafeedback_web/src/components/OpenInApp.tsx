"use client";

import { useCallback, useState } from "react";

import { Brand } from "@/components/Brand";
import { StoreBadges } from "@/components/StoreBadges";

type OpenInAppProps = {
  title: string;
  subtitle: string;
  /** Path after the scheme, e.g. `projects/{id}`. */
  appPath: string;
  /** HTTPS URL for this bridge page (used in Android intent fallback). */
  httpsUrl: string;
  note?: string;
};

function isAndroid(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Android/i.test(navigator.userAgent);
}

/**
 * Bridge page for Universal/App Links. Opening via a plain
 * `href="betafeedback://…"` navigates the browser tab itself, which often
 * bounces focus back from the app. We preventDefault and hand off once.
 */
export function OpenInApp({
  title,
  subtitle,
  appPath,
  httpsUrl: _httpsUrl,
  note,
}: OpenInAppProps) {
  const [opening, setOpening] = useState(false);

  const openApp = useCallback(
    (event: React.MouseEvent<HTMLAnchorElement>) => {
      event.preventDefault();
      if (opening) return;
      setOpening(true);

      const schemeUrl = `betafeedback://${appPath.replace(/^\//, "")}`;

      // Android Intent URL brings the app to the foreground in its own task
      // without leaving the browser on a dead custom-scheme navigation.
      if (isAndroid()) {
        // No browser_fallback_url — user is already on this page; a fallback
        // to the same URL can bounce focus back after the app opens.
        const intentUrl =
          `intent://${appPath.replace(/^\//, "")}` +
          `#Intent;scheme=betafeedback;package=com.betafeedback.app;end`;
        window.location.href = intentUrl;
      } else {
        window.location.href = schemeUrl;
      }

      // Allow a later retry if the handoff failed (app not installed).
      window.setTimeout(() => setOpening(false), 2000);
    },
    [appPath, opening],
  );

  return (
    <div className="join-wrap">
      <main className="join-card">
        <Brand />
        <h1>{title}</h1>
        <p className="join-sub">{subtitle}</p>

        <div className="join-actions">
          <a
            className="btn btn--primary btn--lg"
            href={`betafeedback://${appPath.replace(/^\//, "")}`}
            onClick={openApp}
          >
            {opening ? "Opening…" : "Open in BetaFeedback"}
          </a>
        </div>

        {note ? <p className="join-meta">{note}</p> : null}

        <p className="join-foot" style={{ marginTop: 28 }}>
          Don&apos;t have the app yet?
        </p>
        <StoreBadges variant="light" />
      </main>
    </div>
  );
}
