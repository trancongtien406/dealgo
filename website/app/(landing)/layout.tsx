import type { Metadata } from "next";
import { Be_Vietnam_Pro, Caveat } from "next/font/google";
import type { ReactNode } from "react";
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

export const metadata: Metadata = {
  title: "DealGo – Đi muôn nơi. Mua vạn món. Chủ động cùng DealGo.",
  description:
    "DealGo là ứng dụng đặt xe và giao đồ ăn hàng đầu tại Đà Nẵng. Chủ động thương lượng giá, đặt xe an toàn, tiện lợi và đặt đồ ăn từ hàng nghìn nhà hàng, cửa hàng.",
  keywords: "đặt xe, giao đồ ăn, DealGo, Đà Nẵng, ride hailing, food delivery",
  robots: { index: true, follow: true },
  openGraph: {
    title: "DealGo – Nền tảng Ride & Food hàng đầu",
    description: "Đi muôn nơi. Mua vạn món. Chủ động cùng DealGo.",
    type: "website",
    locale: "vi_VN",
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
