const faqs = [
  {
    q: "How do I find testers?",
    a: "Turn on “Open to test” in your profile to appear when creators are recruiting. As a creator, open Find testers on a project to browse opted-in people, invite them, or propose a test-for-test swap with another creator who’s open to swaps.",
  },
  {
    q: "What is a test-for-test swap?",
    a: "You propose that you’ll test their project if they test yours. They accept from the swaps inbox, and both of you get access as testers — useful when you don’t have a ready tester pool yet.",
  },
  {
    q: "How does the AI turn feedback into a bug?",
    a: "When a tester submits feedback, BetaFeedback drafts a structured report — title, steps to reproduce, expected vs. actual, and severity. It lands as a suggested bug for a developer to confirm or dismiss, so you stay in control.",
  },
  {
    q: "Which platforms can I test?",
    a: "Attach a download or test link for iOS, Android, Web, macOS, Windows, or Linux. Testers grab the right build; all feedback stays in one project.",
  },
  {
    q: "How much does it cost?",
    a: "BetaFeedback is free to start with one project. Pro ($12/mo) adds unlimited projects, CSV export, and email notifications.",
  },
  {
    q: "When is it available?",
    a: "We’re rolling out on iOS and Android. Tap a download badge or email hello@betafeedback.com for early access.",
  },
];

export function FaqSection() {
  return (
    <section className="section" id="faq">
      <div className="container">
        <div className="section__head section__head--left">
          <p className="eyebrow">FAQ</p>
          <h2>Straight answers.</h2>
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
