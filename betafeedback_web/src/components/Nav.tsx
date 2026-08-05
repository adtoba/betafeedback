import Link from "next/link";

import { Brand } from "./Brand";

export function Nav() {
  return (
    <header className="nav">
      <div className="container nav__inner">
        <Brand />
        <nav className="nav__links" aria-label="Primary">
          <Link href="/#how">How it works</Link>
          <Link href="/#features">Features</Link>
          <Link href="/#faq">FAQ</Link>
          <Link href="/#contact">Contact</Link>
        </nav>
        <div className="nav__cta">
          <Link className="btn btn--primary btn--sm" href="/#download">
            Get the app
          </Link>
        </div>
      </div>
    </header>
  );
}
