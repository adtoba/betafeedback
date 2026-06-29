type StoreBadgesProps = {
  variant?: "light" | "dark";
  href?: string;
  mailtoSubject?: string;
};

function AppleIcon({ fill }: { fill: string }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill={fill} aria-hidden="true">
      <path d="M17.05 12.04c-.03-2.85 2.33-4.22 2.44-4.29-1.33-1.95-3.4-2.22-4.13-2.25-1.76-.18-3.43 1.03-4.32 1.03-.89 0-2.26-1.01-3.72-.98-1.91.03-3.68 1.11-4.66 2.82-1.99 3.45-.51 8.55 1.43 11.35.95 1.37 2.08 2.91 3.56 2.85 1.43-.06 1.97-.92 3.7-.92 1.72 0 2.21.92 3.72.89 1.54-.03 2.51-1.39 3.45-2.77 1.09-1.59 1.54-3.13 1.56-3.21-.03-.01-2.99-1.15-3.02-4.55zM14.2 4.38c.79-.96 1.32-2.29 1.18-3.62-1.14.05-2.52.76-3.33 1.72-.73.85-1.37 2.21-1.2 3.51 1.27.1 2.57-.65 3.35-1.61z" />
    </svg>
  );
}

function PlayIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 512 512" aria-hidden="true">
      <path fill="#00C3FF" d="M47.4 11.3C42 17.2 39 26 39 37.4v437.2c0 11.4 3 20.2 8.6 26.1l1.5 1.4L295 257.5v-3L49 9.9z" />
      <path fill="#00F076" d="M376 339.5l-81-81v-3l81-81 1.8 1L474 230c27.7 15.7 27.7 41.5 0 57.3l-96.2 54.6z" />
      <path fill="#FF3A44" d="M377.8 338.5L295 256 47.4 500.7c9.1 9.7 24.2 10.9 41.2 1.2l289.2-164.4" />
      <path fill="#FFC900" d="M377.8 173.5L88.6 9.9C71.6.2 56.5 1.4 47.4 11.1L295 256z" />
    </svg>
  );
}

export function StoreBadges({
  variant = "light",
  href = "#download",
  mailtoSubject,
}: StoreBadgesProps) {
  const className = variant === "light" ? "badges badges--light" : "badges";
  const appleFill = variant === "light" ? "#000" : "#fff";

  const iosHref = mailtoSubject
    ? `mailto:hello@betafeedback.com?subject=${encodeURIComponent(mailtoSubject + " iOS early access")}`
    : href;
  const androidHref = mailtoSubject
    ? `mailto:hello@betafeedback.com?subject=${encodeURIComponent(mailtoSubject + " Android early access")}`
    : href;

  return (
    <div className={className}>
      <a className="badge" href={iosHref} aria-label="Download on the App Store">
        <AppleIcon fill={appleFill} />
        <span className="badge__txt">
          <small>Download on the</small>
          <b>App Store</b>
        </span>
      </a>
      <a className="badge" href={androidHref} aria-label="Get it on Google Play">
        <PlayIcon />
        <span className="badge__txt">
          <small>GET IT ON</small>
          <b>Google Play</b>
        </span>
      </a>
    </div>
  );
}
