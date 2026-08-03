const steps = [
  {
    n: "01",
    title: "Find testers, or swap",
    text: "Browse people who’ve opted in as open to test, invite them with one tap, or propose a test-for-test swap with another creator who needs coverage too.",
  },
  {
    n: "02",
    title: "Testers send feedback",
    text: "They install your build from TestFlight, Play, or a link you attach — then tap to report what’s broken, confusing, or missing.",
  },
  {
    n: "03",
    title: "AI drafts the bug",
    text: "Each report lands as a structured draft: title, repro steps, expected vs. actual, severity. You confirm or dismiss — noise never hits the list.",
  },
];

export function HowItWorksSection() {
  return (
    <section className="section loop" id="how">
      <div className="container">
        <div className="section__head section__head--left">
          <p className="eyebrow">The loop</p>
          <h2>From empty tester list to a clean bug board.</h2>
          <p className="section__sub">
            BetaFeedback isn’t just a feedback form. It’s how you recruit coverage
            and turn what people say into work your team can ship against.
          </p>
        </div>

        <ol className="loop__rail">
          {steps.map((step, i) => (
            <li className="loop__step" key={step.n}>
              <div className="loop__index" aria-hidden="true">
                <span>{step.n}</span>
                {i < steps.length - 1 ? <span className="loop__connector" /> : null}
              </div>
              <div className="loop__body">
                <h3>{step.title}</h3>
                <p>{step.text}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
