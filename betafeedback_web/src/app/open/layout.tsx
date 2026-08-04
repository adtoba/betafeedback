import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Open in BetaFeedback",
  description: "Continue in the BetaFeedback mobile app.",
  robots: { index: false, follow: false },
};

export default function OpenLayout({ children }: { children: React.ReactNode }) {
  return children;
}
