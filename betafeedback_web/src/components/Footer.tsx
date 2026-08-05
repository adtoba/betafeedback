import Link from "next/link";

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
          <Link href="/#how">How it works</Link>
          <Link href="/#features">Features</Link>
          <Link href="/#faq">FAQ</Link>
          <Link href="/contact">Contact</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
        </nav>
        <p className="footer__copy">© {year} BetaFeedback</p>
      </div>
    </footer>
  );
}
