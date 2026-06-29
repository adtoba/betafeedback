import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Join a beta · BetaFeedback",
  description: "You've been invited to test a beta on BetaFeedback.",
  robots: { index: false, follow: false },
};

export default function JoinLayout({ children }: { children: React.ReactNode }) {
  return children;
}
