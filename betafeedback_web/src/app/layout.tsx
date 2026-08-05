import type { Metadata } from "next";
import { Bricolage_Grotesque, IBM_Plex_Sans, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
});

const body = IBM_Plex_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-body",
  display: "swap",
});

const mono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "BetaFeedback — find testers, ship cleaner builds",
  description:
    "BetaFeedback helps you find people open to testing, swap builds with other creators, and turn tester feedback into structured bug reports automatically. Download for iOS and Android.",
  openGraph: {
    title: "BetaFeedback",
    description:
      "Find testers, swap builds, get structured bugs. Download for iOS and Android.",
    type: "website",
    url: "https://betafeedback.com",
  },
  icons: {
    icon: [
      { url: "/brand/app-icon.png", type: "image/png", sizes: "1024x1024" },
      { url: "/favicon.svg", type: "image/svg+xml" },
    ],
    apple: "/brand/app-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
