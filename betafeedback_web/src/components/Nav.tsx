import { Brand } from "./Brand";

export function Nav() {
  return (
    <header className="nav">
      <div className="container nav__inner">
        <Brand />
        <div className="nav__cta">
          <a className="btn btn--white btn--sm" href="#download">
            Get the app
          </a>
        </div>
      </div>
    </header>
  );
}
