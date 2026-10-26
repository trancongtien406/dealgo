import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DealGo – Đi muôn nơi. Mua vạn món. Chủ động cùng DealGo.",
  description:
    "DealGo là ứng dụng đặt xe và giao đồ ăn hàng đầu tại Đà Nẵng. Chủ động thương lượng giá, đặt xe an toàn, tiện lợi và đặt đồ ăn từ hàng nghìn nhà hàng, cửa hàng.",
  keywords: "đặt xe, giao đồ ăn, DealGo, Đà Nẵng, ride hailing, food delivery",
  openGraph: {
    title: "DealGo – Nền tảng Ride & Food hàng đầu",
    description: "Đi muôn nơi. Mua vạn món. Chủ động cùng DealGo.",
    type: "website",
    locale: "vi_VN",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="vi" className="scroll-smooth">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:ital,wght@0,400;0,500;0,600;0,700;0,800;1,400&family=Caveat:wght@600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased">{children}</body>
    </html>
  );
}
