import type { Metadata } from "next";
import Link from "next/link";

import { SiteChrome } from "@/components/SiteChrome";

export const metadata: Metadata = {
  title: "Terms of Service · BetaFeedback",
  description: "Terms that govern your use of BetaFeedback.",
};

export default function TermsPage() {
  return (
    <SiteChrome>
      <article className="legal">
        <div className="container legal__inner">
          <p className="eyebrow">Legal</p>
          <h1>Terms of Service</h1>
          <p className="legal__meta">Last updated: August 5, 2026</p>
          <p className="legal__lede">
            These Terms of Service (“Terms”) govern your access to and use of
            BetaFeedback’s website, mobile apps, and related services
            (together, the “Service”). By creating an account or using the
            Service, you agree to these Terms. If you do not agree, do not use
            BetaFeedback.
          </p>

          <nav className="legal__toc" aria-label="On this page">
            <a href="#service">The Service</a>
            <a href="#accounts">Accounts</a>
            <a href="#content">Your content</a>
            <a href="#acceptable">Acceptable use</a>
            <a href="#subscriptions">Subscriptions</a>
            <a href="#ip">Intellectual property</a>
            <a href="#disclaimer">Disclaimer</a>
            <a href="#liability">Limitation of liability</a>
            <a href="#termination">Termination</a>
            <a href="#law">Governing law</a>
            <a href="#contact">Contact</a>
          </nav>

          <section id="service" className="legal__section">
            <h2>The Service</h2>
            <p>
              BetaFeedback helps creators run betas: create projects, invite
              testers, collect feedback, structure bugs, announce releases, and
              (on Pro) propose test-for-test swaps. Features may change as we
              improve the product. We may offer free and paid plans with
              different limits.
            </p>
          </section>

          <section id="accounts" className="legal__section">
            <h2>Accounts</h2>
            <p>
              You must provide accurate information and keep your sign-in method
              secure. You are responsible for activity under your account. You
              must be at least 13 years old (or the minimum age required in your
              country) to use the Service. If you use BetaFeedback on behalf of
              an organization, you represent that you have authority to bind
              that organization to these Terms.
            </p>
          </section>

          <section id="content" className="legal__section">
            <h2>Your content</h2>
            <p>
              You retain ownership of content you submit (projects, feedback,
              screenshots, comments, messages, and related materials). You grant
              us a worldwide, non-exclusive license to host, store, process,
              display, and transmit that content solely to operate and improve
              the Service for you and people you invite into your projects.
            </p>
            <p>
              You are responsible for the content you upload and for having the
              rights to share it. Do not upload unlawful, harmful, or infringing
              material. Project owners are responsible for how their projects
              are used and who they invite.
            </p>
          </section>

          <section id="acceptable" className="legal__section">
            <h2>Acceptable use</h2>
            <p>You agree not to:</p>
            <ul>
              <li>
                Abuse, harass, or spam other users, or use invites/swaps to
                spam people.
              </li>
              <li>
                Attempt to access accounts, projects, or data you are not
                authorized to use.
              </li>
              <li>
                Reverse engineer, disrupt, or overload the Service, or bypass
                rate limits or security controls.
              </li>
              <li>
                Use BetaFeedback to distribute malware, phishing, or illegal
                software.
              </li>
              <li>
                Misrepresent your identity or affiliation when inviting testers
                or proposing swaps.
              </li>
            </ul>
            <p>
              We may remove content or suspend accounts that violate these
              Terms or create risk for other users.
            </p>
          </section>

          <section id="subscriptions" className="legal__section">
            <h2>Subscriptions &amp; billing</h2>
            <p>
              Free accounts include limited features (currently one full
              project with core beta tools). BetaFeedback Pro is a paid
              auto-renewing subscription that unlocks additional features such
              as unlimited projects and test-for-test swaps. Pricing is shown in
              the app and store listing before you purchase.
            </p>
            <p>
              Purchases made through the Apple App Store or Google Play are
              billed by those platforms under their terms. Manage, cancel, or
              request refunds through the store account used for the purchase.
              Unless required by law, fees are non-refundable once charged.
            </p>
          </section>

          <section id="ip" className="legal__section">
            <h2>Intellectual property</h2>
            <p>
              BetaFeedback, including its branding, software, and site design,
              is owned by us or our licensors. These Terms do not grant you
              rights to our trademarks or code beyond using the Service as
              intended.
            </p>
          </section>

          <section id="disclaimer" className="legal__section">
            <h2>Disclaimer</h2>
            <p>
              The Service is provided “as is” and “as available.” To the fullest
              extent permitted by law, we disclaim warranties of merchantability,
              fitness for a particular purpose, and non-infringement. We do not
              guarantee that betas will be successful, that feedback will be
              accurate, or that the Service will be uninterrupted or error-free.
            </p>
          </section>

          <section id="liability" className="legal__section">
            <h2>Limitation of liability</h2>
            <p>
              To the fullest extent permitted by law, BetaFeedback and its
              operators will not be liable for indirect, incidental, special,
              consequential, or punitive damages, or for lost profits, data, or
              goodwill, arising from your use of the Service. Our total
              liability for any claim relating to the Service is limited to the
              greater of (a) the amounts you paid us for Pro in the 12 months
              before the claim, or (b) USD $50.
            </p>
          </section>

          <section id="termination" className="legal__section">
            <h2>Termination</h2>
            <p>
              You may stop using BetaFeedback at any time. We may suspend or
              terminate access if you violate these Terms or if we discontinue
              the Service. Provisions that by nature should survive (including
              ownership, disclaimers, and limitations of liability) will
              survive termination.
            </p>
          </section>

          <section id="law" className="legal__section">
            <h2>Governing law</h2>
            <p>
              These Terms are governed by the laws of Nigeria, without regard to
              conflict-of-law rules, unless mandatory consumer protections in
              your country of residence require otherwise. Courts in Nigeria
              will have exclusive jurisdiction, subject to those mandatory
              protections.
            </p>
          </section>

          <section id="contact" className="legal__section">
            <h2>Contact</h2>
            <p>
              Questions about these Terms:{" "}
              <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>
              .
            </p>
            <p>
              See also our <Link href="/privacy">Privacy Policy</Link> and{" "}
              <Link href="/contact">Contact</Link> page.
            </p>
          </section>
        </div>
      </article>
    </SiteChrome>
  );
}
