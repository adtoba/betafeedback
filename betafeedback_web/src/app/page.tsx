import { Nav } from "@/components/Nav";
import { Footer } from "@/components/Footer";
import { HeroSection } from "@/components/landing/HeroSection";
import { FeaturesSection } from "@/components/landing/FeaturesSection";
import { TestimonialsSection } from "@/components/landing/TestimonialsSection";
import { PlatformsSection } from "@/components/landing/PlatformsSection";
import { FaqSection } from "@/components/landing/FaqSection";
import { DownloadSection } from "@/components/landing/DownloadSection";

export default function HomePage() {
  return (
    <>
      <Nav />
      <main>
        <HeroSection />
        <FeaturesSection />
        <TestimonialsSection />
        <PlatformsSection />
        <FaqSection />
        <DownloadSection />
        <Footer />
      </main>
    </>
  );
}
