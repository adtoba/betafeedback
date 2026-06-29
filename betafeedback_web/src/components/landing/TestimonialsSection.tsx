const quotes = [
  {
    initials: "JD",
    text: "“Our testers finally send useful reports — because they don’t have to. The AI draft is usually better than what we’d write ourselves.”",
    name: "Jordan Diaz",
    role: "Lead Engineer, Lumen",
  },
  {
    initials: "PA",
    text: "“We cut our beta triage time by more than half. Confirming a clean draft is so much faster than decoding a paragraph.”",
    name: "Priya Anand",
    role: "PM, ShopFlow",
  },
  {
    initials: "MK",
    text: "“One invite link, builds for iOS and Android, every bug in one place. It’s the tool I wish we’d had three betas ago.”",
    name: "Marcus Kane",
    role: "Founder, Driftly",
  },
];

export function TestimonialsSection() {
  return (
    <section className="section" id="reviews" style={{ paddingTop: 0 }}>
      <div className="container">
        <div className="section__head">
          <p className="eyebrow">Loved by beta teams</p>
          <h2>Less triage. More shipping.</h2>
        </div>
        <div className="quotes">
          {quotes.map((q) => (
            <figure className="card quote" key={q.name}>
              <span className="stars" aria-hidden="true">
                ★★★★★
              </span>
              <blockquote className="quote__text">{q.text}</blockquote>
              <figcaption className="quote__who">
                <span className="quote__avatar" aria-hidden="true">
                  {q.initials}
                </span>
                <span>
                  <span className="quote__name">{q.name}</span>
                  <br />
                  <span className="quote__role">{q.role}</span>
                </span>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
