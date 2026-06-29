const faqs = [
  {
    q: "How does the AI turn feedback into a bug?",
    a: "When a tester submits feedback, BetaFeedback classifies whether it’s a defect and, if so, drafts a structured report — title, steps to reproduce, expected vs. actual behavior, and a severity. It lands as a “suggested” bug for a developer to confirm or dismiss, so you stay in control.",
  },
  {
    q: "Which platforms can I test?",
    a: "Any of them. Pick the platforms your build targets — iOS, Android, Web, macOS, Windows, or Linux — and attach a download or test link for each. Testers always grab the right build, and all feedback lands in one project.",
  },
  {
    q: "Who can see and manage bugs?",
    a: "You invite people as testers or developers with a single shareable link. Testers send feedback; developers (and the project creator) confirm AI drafts, set severity, and mark bugs fixed.",
  },
  {
    q: "How much does it cost?",
    a: "BetaFeedback is free to start with one project. Pro ($12/mo) adds unlimited projects, custom logos, CSV export, and email notifications.",
  },
  {
    q: "When is it available?",
    a: "We’re rolling out to iOS and Android. Tap a download badge or email us to get early access and we’ll get you set up.",
  },
];

export function FaqSection() {
  return (
    <section className="section" id="faq" style={{ paddingTop: 0 }}>
      <div className="container">
        <div className="section__head">
          <p className="eyebrow">Good to know</p>
          <h2>Questions, answered.</h2>
        </div>
        <div className="faq">
          {faqs.map((item) => (
            <details key={item.q}>
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
