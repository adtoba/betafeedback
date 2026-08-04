"use client";

import { Brand } from "@/components/Brand";
import { StoreBadges } from "@/components/StoreBadges";

type OpenInAppProps = {
  title: string;
  subtitle: string;
  /** Custom-scheme URL attempted when the user taps Open. */
  appUrl: string;
  /** Optional secondary note under the CTA. */
  note?: string;
};

/**
 * Bridge page for Universal/App Links. If the app isn't installed, the user
 * stays here with store badges. The primary button tries the custom scheme.
 */
export function OpenInApp({ title, subtitle, appUrl, note }: OpenInAppProps) {
  return (
    <div className="join-wrap">
      <main className="join-card">
        <Brand />
        <h1>{title}</h1>
        <p className="join-sub">{subtitle}</p>

        <div className="join-actions">
          <a className="btn btn--primary btn--lg" href={appUrl}>
            Open in BetaFeedback
          </a>
        </div>

        {note ? <p className="join-meta">{note}</p> : null}

        <p className="join-foot" style={{ marginTop: 28 }}>
          Don&apos;t have the app yet?
        </p>
        <StoreBadges
          variant="light"
          mailtoSubject="BetaFeedback early access"
        />
      </main>
    </div>
  );
}
