import { StoreBadges } from "../StoreBadges";
import { PhoneScreenshot } from "./PhoneScreenshot";

export function HeroSection() {
  return (
    <section className="hero">
      <div className="hero__inner">
        <PhoneScreenshot
          side="left"
          src="/screenshots/hero-project.png"
          alt="BetaFeedback project screen showing tester feedback and an AI-suggested bug"
          priority
        />

        <div className="hero__center">
          <div className="hero__icon" aria-hidden="true">
            β
          </div>
          <h1>
            feedback in.
            <br />
            <span className="lc grad">clean bugs out.</span>
          </h1>
          <p className="hero__lede">
            The app that turns what your testers say into developer-ready bug reports — automatically.
          </p>

          <StoreBadges variant="light" />

          <div className="hero__rating">
            <span className="stars" aria-hidden="true">
              ★★★★★
            </span>
            <span>Loved by beta teams shipping mobile apps</span>
          </div>
        </div>

        <PhoneScreenshot
          side="right"
          src="/screenshots/hero-bugs.png"
          alt="BetaFeedback bug summary screen with open and fixed issues"
          priority
        />
      </div>
    </section>
  );
}
