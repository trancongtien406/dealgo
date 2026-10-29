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
import { getPublicSiteConfig } from "@/features/site-config/fetch-public";
import { qrSvg } from "@/features/site-config/qr";
import { landingJsonLd } from "@/lib/seo/site";

/** Admin-managed links (store, socials) refresh via ISR. */
export const revalidate = 60;

export default async function Home() {
  const siteConfig = await getPublicSiteConfig();
  const qr = await Promise.all(
    [
      siteConfig.appStoreUrl ? { label: "App Store", url: siteConfig.appStoreUrl } : null,
      siteConfig.googlePlayUrl ? { label: "Google Play", url: siteConfig.googlePlayUrl } : null,
    ]
      .filter((x): x is { label: string; url: string } => x !== null)
      .map(async (x) => ({ label: x.label, svg: await qrSvg(x.url) })),
  );
  return (
    <>
      {/* JSON-LD is a data block, not executed script, so script-src CSP does not apply. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(landingJsonLd(siteConfig)).replace(/</g, "\\u003c"),
        }}
      />
      <Navbar />
      <main>
        <HeroSection siteConfig={siteConfig} />
        <ServicesSection />
        <HowItWorksSection />
        <AppExperienceSection />
        <TrustSection />
        <PartnerSection />
        <CitiesSection comingSoon={siteConfig.comingSoonCities} />

        {/* 2-Column Row: FAQ on Left & App Download Banner on Right */}
        <section
          id="faq"
          className="pt-2 sm:pt-3 pb-8 sm:pb-10 bg-white scroll-mt-24"
        >
          <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12 grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch">
            {/* Left Column: FAQ */}
            <div className="lg:col-span-5 h-full">
              <FaqSection />
            </div>

            {/* Right Column: CTA Banner */}
            <div className="lg:col-span-7 h-full">
              <CtaBanner siteConfig={siteConfig} qr={qr} />
            </div>
          </div>
        </section>
      </main>
      <Footer siteConfig={siteConfig} />
    </>
  );
}
