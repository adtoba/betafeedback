import { Brand } from "./Brand";

export function Nav() {
  return (
    <header className="nav">
      <div className="container nav__inner">
        <Brand />
        <nav className="nav__links" aria-label="Primary">
          <a href="#how">How it works</a>
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
        </nav>
        <div className="nav__cta">
          <a className="btn btn--ghost btn--sm" href="/app/login">
            Sign in
          </a>
          <a className="btn btn--primary btn--sm" href="#download">
            Get the app
          </a>
        </div>
      </div>
    </header>
  );
}
