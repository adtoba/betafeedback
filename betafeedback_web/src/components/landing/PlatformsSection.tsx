const platforms = [
  { name: "iOS", hint: "TestFlight" },
  { name: "Android", hint: "Play track" },
  { name: "Web", hint: "Staging URL" },
  { name: "macOS", hint: "Build link" },
  { name: "Windows", hint: "Build link" },
  { name: "Linux", hint: "Build link" },
];

export function PlatformsSection() {
  return (
    <section className="section platforms-sec" id="platforms">
      <div className="container platforms-sec__inner">
        <div className="section__head section__head--left platforms-sec__copy">
          <p className="eyebrow">Targets</p>
          <h2>One project. Every platform you ship.</h2>
          <p className="section__sub">
            Attach a build link per platform. Testers always get the right
            install — feedback still lands in the same board.
          </p>
        </div>
        <ul className="platforms">
          {platforms.map((p) => (
            <li key={p.name}>
              <span className="platforms__name">{p.name}</span>
              <span className="platforms__hint">{p.hint}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
