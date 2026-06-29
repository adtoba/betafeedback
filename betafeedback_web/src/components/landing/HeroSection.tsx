import { StoreBadges } from "../StoreBadges";

function PhoneStatusBar() {
  return (
    <div className="appui__status">
      <span>9:41</span>
      <span className="dots">
        <i />
        <i />
        <i />
      </span>
    </div>
  );
}

function LeftPhone() {
  return (
    <div className="hero__phone hero__phone--left" aria-hidden="true">
      <div className="phone">
        <span className="phone__island" />
        <div className="phone__screen">
          <div className="appui">
            <PhoneStatusBar />
            <div className="appui__bar">
              <small>PROJECT</small>
              <h4>ShopFlow Beta</h4>
              <div className="meta">12 testers · 3 developers</div>
            </div>
            <div className="appui__body">
              <div className="acard">
                <div className="appui__feedback">
                  <span className="appui__avatar" />
                  <div>
                    <p style={{ color: "#1c1530", fontWeight: 700, fontSize: ".76rem" }}>
                      Maya · tester
                    </p>
                    <p>“App closes when I apply an expired promo code at checkout.”</p>
                  </div>
                </div>
              </div>
              <div className="acard">
                <div className="acard__top">
                  <span className="tag tag--suggested">✦ SUGGESTED</span>
                  <span className="tag tag--sev">High</span>
                </div>
                <h5>Checkout crashes on expired promo code</h5>
                <span className="acard__label">Steps</span>
                <p>1. Add item → 2. Enter SPRING23 → 3. Apply</p>
                <div className="acard__row">
                  <span className="acard__btn acard__btn--ghost">Dismiss</span>
                  <span className="acard__btn acard__btn--fill">Confirm bug</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function RightPhone() {
  return (
    <div className="hero__phone hero__phone--right" aria-hidden="true">
      <div className="phone">
        <span className="phone__island" />
        <div className="phone__screen">
          <div className="appui">
            <PhoneStatusBar />
            <div className="appui__bar">
              <small>BUG SUMMARY</small>
              <h4>ShopFlow Beta</h4>
              <div className="meta">3 open · 1 fixed</div>
            </div>
            <div className="appui__body">
              <div className="acard">
                <div className="acard__top">
                  <span className="tag tag--open">● OPEN</span>
                  <span className="tag tag--sev">Critical</span>
                </div>
                <h5>Login fails with “network error” on Wi-Fi</h5>
                <span className="acard__label">Expected</span>
                <p>User signs in successfully.</p>
                <span className="acard__label">Actual</span>
                <p>“Network error” appears every attempt.</p>
              </div>
              <div className="acard">
                <div className="acard__top">
                  <span className="tag tag--fixed">✓ FIXED</span>
                </div>
                <h5>Avatar image stretched on profile</h5>
                <p
                  style={{
                    color: "#0e8a55",
                    fontWeight: 700,
                    fontSize: ".66rem",
                    marginTop: 5,
                  }}
                >
                  Fixed 2h ago
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function HeroSection() {
  return (
    <section className="hero">
      <div className="hero__inner">
        <LeftPhone />

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

        <RightPhone />
      </div>
    </section>
  );
}
