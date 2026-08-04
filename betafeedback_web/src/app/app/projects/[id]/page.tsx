import { redirect } from "next/navigation";

type PageProps = {
  params: Promise<{ id: string }>;
};

/** Old dashboard project URLs redirect to the open-in-app bridge. */
export default async function LegacyProjectRedirect({ params }: PageProps) {
  const { id } = await params;
  redirect(`/open/projects/${encodeURIComponent(id)}`);
}
