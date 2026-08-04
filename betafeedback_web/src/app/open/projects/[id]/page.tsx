import type { Metadata } from "next";

import { OpenInApp } from "@/components/OpenInApp";

type PageProps = {
  params: Promise<{ id: string }>;
};

export const metadata: Metadata = {
  title: "Open in BetaFeedback",
  description: "Continue in the BetaFeedback mobile app.",
  robots: { index: false, follow: false },
};

export default async function OpenProjectPage({ params }: PageProps) {
  const { id } = await params;
  const projectId = decodeURIComponent(id ?? "").trim();
  const appPath = projectId ? `projects/${projectId}` : "";
  const httpsUrl = projectId
    ? `https://betafeedback.com/open/projects/${encodeURIComponent(projectId)}`
    : "https://betafeedback.com";

  return (
    <OpenInApp
      title="Continue in the app"
      subtitle="This link opens your project in BetaFeedback. If nothing happens, install the app and try again."
      appPath={appPath}
      httpsUrl={httpsUrl}
      note={
        projectId
          ? "Already installed? Tap Open in BetaFeedback above."
          : undefined
      }
    />
  );
}
