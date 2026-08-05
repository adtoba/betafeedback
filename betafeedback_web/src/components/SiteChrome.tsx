import { Nav } from "@/components/Nav";
import { Footer } from "@/components/Footer";

/** Shared chrome for marketing + legal pages. */
export function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <>
      <Nav />
      <main>{children}</main>
      <Footer />
    </>
  );
}
