import { Brand } from "./Brand";

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="footer">
      <div className="container footer__inner">
        <Brand />
        <p className="footer__copy">© {year} BetaFeedback. All rights reserved.</p>
        <nav className="footer__links" aria-label="Footer">
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a href="mailto:hello@betafeedback.com">Contact</a>
        </nav>
      </div>
    </footer>
  );
}
