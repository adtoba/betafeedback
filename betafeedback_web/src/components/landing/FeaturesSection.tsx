const features = [
  {
    icon: "✨",
    title: "AI bug structuring",
    text: "Every report is auto-drafted into a clean bug — title, repro steps, expected vs. actual, and severity.",
  },
  {
    icon: "✅",
    title: "Human in the loop",
    text: "AI drafts land as suggestions. A developer confirms or dismisses, so noise never hits your bug list.",
  },
  {
    icon: "📦",
    title: "Multi-platform builds",
    text: "Attach a test link per platform — TestFlight, Play Store, web, or desktop — so testers grab the right build.",
  },
  {
    icon: "👥",
    title: "Roles & invites",
    text: "Invite testers and developers with one shareable link. Each role sees exactly what it needs.",
  },
  {
    icon: "📊",
    title: "Severity triage",
    text: "Bugs arrive pre-tagged Low → Critical, so the team always knows what to pick up first.",
  },
  {
    icon: "⚡",
    title: "Activity & releases",
    text: "A live log of structured bugs, fixes, and releases keeps everyone aligned — no status meeting.",
  },
];

export function FeaturesSection() {
  return (
    <section className="section" id="features">
      <div className="container">
        <div className="section__head">
          <p className="eyebrow">Why teams love it</p>
          <h2>Everything between “it’s broken” and “it’s fixed.”</h2>
        </div>
        <div className="features">
          {features.map((f) => (
            <article className="card feature" key={f.title}>
              <div className="feature__icon" aria-hidden="true">
                {f.icon}
              </div>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
