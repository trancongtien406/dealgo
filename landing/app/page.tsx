import { Navbar } from "@/components/navbar";
import { HeroSection } from "@/components/hero-section";
import { ServicesSection } from "@/components/services-section";
import { FoodShowcaseSection } from "@/components/food-showcase-section";
import { DealFeatureSection } from "@/components/deal-feature-section";
import { PartnersSection } from "@/components/partners-section";
import { AppDownloadSection } from "@/components/app-download-section";
import { FaqSection } from "@/components/faq-section";
import { Footer } from "@/components/footer";

export default function LandingPage() {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="flex-1">
        <HeroSection />
        <ServicesSection />
        <FoodShowcaseSection />
        <DealFeatureSection />
        <PartnersSection />
        <AppDownloadSection />
        <FaqSection />
      </main>
      <Footer />
    </div>
  );
}

