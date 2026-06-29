import Image from "next/image";

const SHOT_WIDTH = 1206;
const SHOT_HEIGHT = 2622;

type PhoneScreenshotProps = {
  src: string;
  alt: string;
  side: "left" | "right";
  priority?: boolean;
};

export function PhoneScreenshot({ src, alt, side, priority }: PhoneScreenshotProps) {
  return (
    <div className={`hero__phone hero__phone--${side}`}>
      <Image
        src={src}
        alt={alt}
        width={SHOT_WIDTH}
        height={SHOT_HEIGHT}
        sizes="(min-width: 1024px) 260px, 0px"
        className="hero__shot"
        priority={priority}
      />
    </div>
  );
}
