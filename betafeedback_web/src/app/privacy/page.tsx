import type { Metadata } from "next";
import Link from "next/link";

import { SiteChrome } from "@/components/SiteChrome";

export const metadata: Metadata = {
  title: "Privacy Policy · BetaFeedback",
  description:
    "How BetaFeedback collects, uses, and protects your information.",
};

export default function PrivacyPage() {
  return (
    <SiteChrome>
      <article className="legal">
        <div className="container legal__inner">
          <p className="eyebrow">Legal</p>
          <h1>Privacy Policy</h1>
          <p className="legal__meta">Last updated: August 14, 2026</p>
          <p className="legal__lede">
            This policy explains what BetaFeedback (“we”, “us”) collects when
            you use our website and mobile apps, how we use it, and the choices
            you have. If you have questions, email{" "}
            <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>.
          </p>

          <nav className="legal__toc" aria-label="On this page">
            <a href="#who">Who we are</a>
            <a href="#collect">What we collect</a>
            <a href="#use">How we use data</a>
            <a href="#share">Sharing</a>
            <a href="#retention">Retention</a>
            <a href="#rights">Your rights</a>
            <a href="#children">Children</a>
            <a href="#changes">Changes</a>
            <a href="#contact">Contact</a>
          </nav>

          <section id="who" className="legal__section">
            <h2>Who we are</h2>
            <p>
              BetaFeedback is a beta-testing product that helps creators invite
              testers, collect feedback, and turn reports into structured bugs.
              The service is available at{" "}
              <a href="https://betafeedback.com">betafeedback.com</a> and in
              our iOS and Android apps.
            </p>
          </section>

          <section id="collect" className="legal__section">
            <h2>What we collect</h2>
            <p>Depending on how you use BetaFeedback, we may collect:</p>
            <ul>
              <li>
                <strong>Account information</strong> — email address, name, and
                profile details you provide (including optional tester bio and
                preferences).
              </li>
              <li>
                <strong>Authentication data</strong> — one-time sign-in codes
                sent by email, or identifiers from Google Sign-In if you choose
                that option.
              </li>
              <li>
                <strong>Project &amp; collaboration content</strong> — projects
                you create, invites, memberships, test-for-test swap proposals,
                feedback, comments, release notes, and related metadata.
              </li>
              <li>
                <strong>Media you attach</strong> — screenshots or screen
                recordings you choose to upload with feedback (we only access
                your photo library when you pick media in the app).
              </li>
              <li>
                <strong>Device &amp; push data</strong> — device tokens used to
                deliver push notifications if you enable them, plus basic
                device/app context you submit with feedback (for example device
                model or app version).
              </li>
              <li>
                <strong>Purchase information</strong> — subscription status for
                BetaFeedback Pro. Payments are processed by Apple or Google via
                RevenueCat; we do not store your full payment card details.
              </li>
              <li>
                <strong>Usage &amp; technical logs</strong> — IP address,
                approximate region, app version, and diagnostic logs needed to
                operate and secure the service.
              </li>
            </ul>
          </section>

          <section id="use" className="legal__section">
            <h2>How we use data</h2>
            <p>We use personal data to:</p>
            <ul>
              <li>Create and secure your account, and sign you in.</li>
              <li>
                Operate projects, invites, feedback, bugs, releases, and
                notifications.
              </li>
              <li>
                Send transactional email (sign-in codes, invites, and product
                alerts you enable).
              </li>
              <li>
                Process Pro subscriptions and restore purchase status across
                devices.
              </li>
              <li>
                Improve reliability and safety (troubleshooting, abuse
                prevention, and service quality).
              </li>
              <li>Respond to support requests you send us.</li>
            </ul>
            <p>
              We may use automated tools (including AI) to draft structured bug
              reports from feedback you submit. Suggested bugs are reviewable by
              project developers before they become confirmed issues.
            </p>
            <p>
              We do not sell your personal information. We do not use your
              content to train third-party foundation models for advertising.
            </p>
          </section>

          <section id="share" className="legal__section">
            <h2>How we share information</h2>
            <p>We share data only as needed to run BetaFeedback:</p>
            <ul>
              <li>
                <strong>With project members</strong> — content you post in a
                project (feedback, media, comments) is visible to people with
                access to that project.
              </li>
              <li>
                <strong>Service providers</strong> — infrastructure and tools
                that process data on our behalf, such as hosting, email delivery
                (e.g. Resend), push delivery (e.g. Firebase Cloud Messaging),
                and subscription management (RevenueCat / Apple / Google).
              </li>
              <li>
                <strong>Legal &amp; safety</strong> — if required by law, or to
                protect users, the service, or our rights.
              </li>
            </ul>
          </section>

          <section id="retention" className="legal__section">
            <h2>Retention</h2>
            <p>
              We keep account and project data while your account is active and
              as needed to provide the service. You can delete your account in
              the app under <strong>Profile → Delete account</strong>. That
              removes your account, projects you created, and personal data. You
              can also email{" "}
              <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>
              . We may retain limited records where required for legal,
              security, or billing purposes.
            </p>
          </section>

          <section id="rights" className="legal__section">
            <h2>Your rights &amp; choices</h2>
            <ul>
              <li>
                Update profile and notification preferences in the app where
                available.
              </li>
              <li>
                Disable push notifications in system settings, or turn off email
                notifications in the app.
              </li>
              <li>
                Manage or cancel Pro in your Apple App Store or Google Play
                subscription settings.
              </li>
              <li>
                Request access, correction, or deletion of your personal data by
                contacting us, or delete your account in the app.
              </li>
              <li>
                Report or block another user from their profile, a feedback
                card, or Find testers.
              </li>
            </ul>
            <p>
              Depending on where you live, you may have additional rights under
              local law (for example GDPR or CCPA). We will respond to verified
              requests within a reasonable time.
            </p>
          </section>

          <section id="children" className="legal__section">
            <h2>Children</h2>
            <p>
              BetaFeedback is not directed to children under 13, and we do not
              knowingly collect personal information from children under 13. If
              you believe a child has provided us data, contact us and we will
              take appropriate steps to delete it.
            </p>
          </section>

          <section id="changes" className="legal__section">
            <h2>Changes to this policy</h2>
            <p>
              We may update this Privacy Policy from time to time. We will post
              the revised version on this page and update the “Last updated”
              date. Continued use of BetaFeedback after changes means you accept
              the updated policy.
            </p>
          </section>

          <section id="contact" className="legal__section">
            <h2>Contact</h2>
            <p>
              Privacy questions or requests:{" "}
              <a href="mailto:hello@betafeedback.com">hello@betafeedback.com</a>
              .
            </p>
            <p>
              More ways to reach us: <Link href="/contact">Contact</Link>. Also
              see our <Link href="/terms">Terms of Service</Link>.
            </p>
          </section>
        </div>
      </article>
    </SiteChrome>
  );
}
