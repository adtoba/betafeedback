const faqs = [
  {
    q: "How do I find testers?",
    a: "Turn on “Open to test” in your profile to appear when creators are recruiting. As a creator, open Find testers on a project to browse opted-in people and invite them. Test-for-test swaps with other creators are available on Pro.",
  },
  {
    q: "What is a test-for-test swap?",
    a: "A Pro feature: you propose that you’ll test their project if they test yours. They accept from the swaps inbox, and both of you get access as testers — useful when you don’t have a ready tester pool yet.",
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
    a: "Free includes one full project — invites, AI bug structuring, CSV export, and email notifications. Pro ($12/mo) adds unlimited projects and test-for-test swaps.",
  },
  {
    q: "When is it available?",
    a: "BetaFeedback is live on the App Store for iPhone and iPad. Android is coming soon — email hello@betafeedback.com if you want a heads-up when it ships.",
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
