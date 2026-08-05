import Link from "next/link";

/** Inline SVG — transparent canvas, no PNG white corners. */
function BrandMarkIcon({ size = 34 }: { size?: number }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 64 64"
      width={size}
      height={size}
      fill="none"
      aria-hidden="true"
    >
      <rect width="64" height="64" rx="14" fill="#1256E0" />
      <path
        stroke="#FFFFFF"
        strokeWidth="6.75"
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M23 13.5V46.5c0 6.5 5.2 10.5 12.5 10.5C44 57 50 51.8 50 44.5c0-6.5-4.8-10.3-12.5-11.5C44.8 31.5 49.5 26.8 49.5 20.5 49.5 13.2 43 9.5 34.5 9.5c-4.3 0-8.3 1.1-11.5 3.3"
      />
      <path
        fill="#FFFFFF"
        d="M23.5 54.5 14.8 47.6c-.8-.6-.8-1.9 0-2.5l8.7-6.9c1-.8 2.5-.1 2.5 1.2v3.8h9.5c1 0 1.8.8 1.8 1.8s-.8 1.8-1.8 1.8H26v3.8c0 1.3-1.5 2-2.5 1.9Z"
      />
    </svg>
  );
}

export function Brand() {
  return (
    <Link className="brand" href="/" aria-label="BetaFeedback home">
      <span className="brand__mark" aria-hidden="true">
        <BrandMarkIcon />
      </span>
      <span className="brand__name">BetaFeedback</span>
    </Link>
  );
}
