export function ContactSection() {
  return (
    <section id="contact" className="section contact">
      <div className="container">
        <div className="section__head section__head--left">
          <p className="eyebrow">Contact</p>
          <h2>Write us. We read every note.</h2>
          <p className="section__sub">
            Support, early access, partnerships, or press — one inbox, real
            humans.
          </p>
        </div>

        <div className="contact__grid">
          <a
            className="contact__card"
            href="mailto:hello@betafeedback.com?subject=BetaFeedback%20support"
          >
            <span className="contact__label">Support</span>
            <strong>Account, billing, or product help</strong>
            <span className="contact__email">hello@betafeedback.com</span>
          </a>
          <a
            className="contact__card"
            href="mailto:hello@betafeedback.com?subject=BetaFeedback%20early%20access"
          >
            <span className="contact__label">Early access</span>
            <strong>Get on iOS or Android when seats open</strong>
            <span className="contact__email">hello@betafeedback.com</span>
          </a>
          <a
            className="contact__card"
            href="mailto:hello@betafeedback.com?subject=BetaFeedback%20partnership"
          >
            <span className="contact__label">Partnerships</span>
            <strong>Press, collabs, and creator programs</strong>
            <span className="contact__email">hello@betafeedback.com</span>
          </a>
        </div>
      </div>
    </section>
  );
}
