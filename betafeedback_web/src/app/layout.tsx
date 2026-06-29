import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "BetaFeedback — feedback in, clean bugs out",
  description:
    "BetaFeedback is the app for running your beta. Testers tap to send feedback, AI turns it into clean bug reports, your team confirms and ships. Download for iOS and Android.",
  openGraph: {
    title: "BetaFeedback",
    description: "Feedback in, clean bugs out. Download for iOS and Android.",
    type: "website",
    url: "https://betafeedback.com",
  },
  icons: {
    icon: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
