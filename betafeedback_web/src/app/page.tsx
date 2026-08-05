import { Nav } from "@/components/Nav";
import { Footer } from "@/components/Footer";
import { HeroSection } from "@/components/landing/HeroSection";
import { HowItWorksSection } from "@/components/landing/HowItWorksSection";
import { FeaturesSection } from "@/components/landing/FeaturesSection";
import { PlatformsSection } from "@/components/landing/PlatformsSection";
import { FaqSection } from "@/components/landing/FaqSection";
import { ContactSection } from "@/components/landing/ContactSection";
import { DownloadSection } from "@/components/landing/DownloadSection";

export default function HomePage() {
  return (
    <>
      <Nav />
      <main>
        <HeroSection />
        <HowItWorksSection />
        <FeaturesSection />
        <PlatformsSection />
        <FaqSection />
        <ContactSection />
        <DownloadSection />
      </main>
      <Footer />
    </>
  );
}
