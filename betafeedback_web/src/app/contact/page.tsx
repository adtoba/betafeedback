import type { Metadata } from "next";
import Link from "next/link";

import { SiteChrome } from "@/components/SiteChrome";

export const metadata: Metadata = {
  title: "Contact · BetaFeedback",
  description:
    "Contact BetaFeedback for support, early access, partnerships, or press.",
};

export default function ContactPage() {
  return (
    <SiteChrome>
      <section className="legal">
        <div className="container legal__inner">
          <p className="eyebrow">Contact</p>
          <h1>Get in touch</h1>
          <p className="legal__lede">
            We read every message. Use the topics below or email{" "}
            <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>{" "}
            directly — we usually reply within one business day.
          </p>

          <div className="contact__grid contact__grid--page">
            <a
              className="contact__card"
              href="mailto:hello@betafeedback.com?subject=BetaFeedback%20support"
            >
              <span className="contact__label">Support</span>
              <strong>Account, billing, bugs, or how-to questions</strong>
              <span className="contact__email">hello@betafeedback.com</span>
            </a>
            <a
              className="contact__card"
              href="mailto:hello@betafeedback.com?subject=BetaFeedback%20early%20access"
            >
              <span className="contact__label">Early access</span>
              <strong>Request iOS or Android access</strong>
              <span className="contact__email">hello@betafeedback.com</span>
            </a>
            <a
              className="contact__card"
              href="mailto:hello@betafeedback.com?subject=BetaFeedback%20partnership"
            >
              <span className="contact__label">Partnerships &amp; press</span>
              <strong>Collabs, creator programs, media</strong>
              <span className="contact__email">hello@betafeedback.com</span>
            </a>
          </div>

          <p className="legal__note">
            For privacy requests, see our{" "}
            <Link href="/privacy">Privacy Policy</Link>. For product rules, see{" "}
            <Link href="/terms">Terms of Service</Link>.
          </p>
        </div>
      </section>
    </SiteChrome>
  );
}
