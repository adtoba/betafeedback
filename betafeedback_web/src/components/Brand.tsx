import Image from "next/image";
import Link from "next/link";

/** Same full-bleed mark as the mobile app icon. */
export function Brand() {
  return (
    <Link className="brand" href="/" aria-label="BetaFeedback home">
      <span className="brand__mark" aria-hidden="true">
        <Image
          src="/brand/app-icon.png"
          alt=""
          width={34}
          height={34}
          priority
        />
      </span>
      <span className="brand__name">BetaFeedback</span>
    </Link>
  );
}
