const features = [
  {
    label: "Network",
    title: "Open to test",
    text: "Creators browse testers who’ve opted in — devices, platforms, and a short bio — then invite the right people instead of blasting a group chat.",
  },
  {
    label: "Reciprocity",
    title: "Test-for-test swaps",
    text: "Propose a swap: you test their build, they test yours. Accept from the swaps inbox and both projects get a tester without hunting.",
  },
  {
    label: "Structure",
    title: "AI bug drafts",
    text: "Feedback becomes a developer-ready report — title, steps, expected vs. actual, severity — sitting as a suggestion until you confirm.",
  },
  {
    label: "Builds",
    title: "Multi-platform links",
    text: "Attach TestFlight, Play Store, web, or desktop links per platform so every tester grabs the right build from one project.",
  },
  {
    label: "Control",
    title: "Human in the loop",
    text: "AI never writes to your bug list alone. Developers confirm or dismiss drafts, set severity, and mark fixes when they’re done.",
  },
  {
    label: "Roles",
    title: "Invites that fit",
    text: "One shareable link. Testers send feedback; developers triage. Everyone sees the slice of the project they need.",
  },
];

export function FeaturesSection() {
  return (
    <section className="section" id="features">
      <div className="container">
        <div className="section__head section__head--left">
          <p className="eyebrow">What’s inside</p>
          <h2>Built for the messy middle of a beta.</h2>
          <p className="section__sub">
            Recruiting, reporting, and triage in one place — so “it’s broken”
            turns into something you can actually fix.
          </p>
        </div>
        <div className="features">
          {features.map((f) => (
            <article className="feature" key={f.title}>
              <p className="feature__label">{f.label}</p>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
