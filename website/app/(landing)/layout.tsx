import type { Metadata } from "next";
import { Be_Vietnam_Pro, Caveat } from "next/font/google";
import type { ReactNode } from "react";
import { SITE_DESCRIPTION, SITE_NAME } from "@/lib/seo/site";
import "./landing.css";

const beVietnamPro = Be_Vietnam_Pro({
  subsets: ["latin", "vietnamese"],
  weight: ["400", "500", "600", "700", "800"],
  style: ["normal", "italic"],
  variable: "--font-be-vietnam-pro",
});

const caveat = Caveat({
  subsets: ["latin"],
  weight: ["600", "700"],
  variable: "--font-caveat",
});

const TITLE = "DealGo – Đặt xe thương lượng giá và đặt đồ ăn tại Đà Nẵng";

export const metadata: Metadata = {
  title: { absolute: TITLE },
  description: SITE_DESCRIPTION,
  keywords: [
    "DealGo",
    "đặt xe",
    "xe máy",
    "ô tô",
    "thương lượng giá",
    "đặt đồ ăn",
    "giao đồ ăn",
    "Đà Nẵng",
  ],
  robots: { index: true, follow: true },
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: SITE_NAME,
    title: TITLE,
    description: SITE_DESCRIPTION,
    locale: "vi_VN",
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: SITE_DESCRIPTION,
  },
};

/** Public marketing landing. Styles are scoped to `.landing-root`. */
export default function LandingLayout({ children }: { children: ReactNode }) {
  return (
    <div
      className={`landing-root ${beVietnamPro.variable} ${caveat.variable} min-h-full antialiased`}
    >
      {children}
    </div>
  );
}
