import { StoreBadges } from "../StoreBadges";

export function DownloadSection() {
  return (
    <section id="download" className="download">
      <div className="ctacard">
        <p className="eyebrow eyebrow--on-brand">Get the app</p>
        <h2>Spin up a beta. Fill the tester seats.</h2>
        <p>
          Create a project, find people open to testing or propose a swap, and
          let structured bugs come to you.
        </p>
        <StoreBadges variant="dark" />
        <p className="ctacard__meta">
          Free to start on iOS · Android coming soon · Questions?{" "}
          <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>
        </p>
      </div>
    </section>
  );
}
