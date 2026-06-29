import Link from "next/link";

export function Brand() {
  return (
    <Link className="brand" href="/" aria-label="BetaFeedback home">
      <span className="brand__mark" aria-hidden="true">
        β
      </span>
      <span className="brand__name">BetaFeedback</span>
    </Link>
  );
}
