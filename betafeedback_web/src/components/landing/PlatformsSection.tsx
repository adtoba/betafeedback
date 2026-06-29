const platforms = ["iOS", "Android", "Web", "macOS", "Windows", "Linux"];

export function PlatformsSection() {
  return (
    <section className="section" id="platforms" style={{ paddingTop: 0 }}>
      <div className="container">
        <div className="section__head">
          <p className="eyebrow">Built for every target</p>
          <h2>Test on anything.</h2>
          <p className="section__sub">
            Attach a build link per platform — BetaFeedback keeps every tester’s feedback in one place.
          </p>
        </div>
        <ul className="platforms">
          {platforms.map((p) => (
            <li key={p}>
              <span className="platforms__icon" />
              {p}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
