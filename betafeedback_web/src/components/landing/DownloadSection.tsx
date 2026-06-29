import { StoreBadges } from "../StoreBadges";

export function DownloadSection() {
  return (
    <section id="download" style={{ padding: "0 22px 88px" }}>
      <div className="ctacard">
        <h2>Get BetaFeedback</h2>
        <p>
          Free to start. Spin up a project, invite your testers, and let the structured bugs come to you.
        </p>
        <StoreBadges variant="dark" mailtoSubject="BetaFeedback" />
        <p className="ctacard__meta">
          Launching soon — tap a badge to get notified, or email{" "}
          <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>
        </p>
      </div>
    </section>
  );
}
