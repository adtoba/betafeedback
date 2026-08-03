import { Brand } from "./Brand";

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="footer">
      <div className="container footer__inner">
        <div className="footer__brand">
          <Brand />
          <p className="footer__tag">Find testers. Ship cleaner builds.</p>
        </div>
        <nav className="footer__links" aria-label="Footer">
          <a href="#how">How it works</a>
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a href="mailto:hello@betafeedback.com">Contact</a>
        </nav>
        <p className="footer__copy">© {year} BetaFeedback</p>
      </div>
    </footer>
  );
}
