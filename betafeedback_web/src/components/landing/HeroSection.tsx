import { StoreBadges } from "../StoreBadges";
import { PhoneScreenshot } from "./PhoneScreenshot";

export function HeroSection() {
  return (
    <section className="hero">
      <div className="hero__glow" aria-hidden="true" />
      <div className="hero__inner">
        <PhoneScreenshot
          side="left"
          src="/screenshots/test-detail.png"
          alt="BetaFeedback project screen showing tester feedback and an AI-suggested bug"
          priority
        />

        <div className="hero__center">
          {/* <p className="hero__signal">
            <span className="hero__signal-dot" aria-hidden="true" />
            Open to test · Test-for-test swaps · AI bug drafts
          </p> */}
          <h1>
            feedback in.
            <br />
            <span className="lc grad">clean bugs out.</span>
          </h1>
          <p className="hero__lede">
            Find people open to testing your build, swap testing with other
            creators, and turn every report into a structured bug — title,
            steps, severity — ready to confirm.
          </p>

          <StoreBadges variant="light" />

          <p className="hero__meta">
            Free to start · iOS &amp; Android · Early access open
          </p>
        </div>

        <PhoneScreenshot
          side="right"
          src="/screenshots/test-for-test.png"
          alt="BetaFeedback bug summary screen with open and fixed issues"
          priority
        />
      </div>
    </section>
  );
}
