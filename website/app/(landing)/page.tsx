import Navbar from "@/components/landing/Navbar";
import HeroSection from "@/components/landing/HeroSection";
import ServicesSection from "@/components/landing/ServicesSection";
import HowItWorksSection from "@/components/landing/HowItWorksSection";
import AppExperienceSection from "@/components/landing/AppExperienceSection";
import TrustSection from "@/components/landing/TrustSection";
import PartnerSection from "@/components/landing/PartnerSection";
import CitiesSection from "@/components/landing/CitiesSection";
import FaqSection from "@/components/landing/FaqSection";
import CtaBanner from "@/components/landing/CtaBanner";
import Footer from "@/components/landing/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <HeroSection />
        <ServicesSection />
        <HowItWorksSection />
        <AppExperienceSection />
        <TrustSection />
        <PartnerSection />
        <CitiesSection />

        {/* 2-Column Row: FAQ on Left & App Download Banner on Right */}
        <section id="faq" className="pt-2 sm:pt-3 pb-8 sm:pb-10 bg-white scroll-mt-24">
          <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12 grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch">
            {/* Left Column: FAQ */}
            <div className="lg:col-span-5 h-full">
              <FaqSection />
            </div>

            {/* Right Column: CTA Banner */}
            <div className="lg:col-span-7 h-full">
              <CtaBanner />
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
