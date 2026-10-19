import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DealGo — Di chuyển thông minh, Ẩm thực linh hoạt với tính năng Deal Giá",
  description:
    "DealGo là nền tảng gọi xe hai bánh và giao đồ ăn hàng đầu với tính năng Deal Giá độc quyền. Khách hàng chủ động giá tốt, Tài xế & Quán ăn tăng thu nhập công bằng.",
  keywords: [
    "DealGo",
    "gọi xe DealGo",
    "deal giá",
    "xe ôm công nghệ",
    "giao đồ ăn",
    "đặt xe hai bánh",
    "DealGo Food",
    "DealGo Ride",
  ],
  authors: [{ name: "DealGo Platform" }],
  icons: {
    icon: "/dealgo-icon.svg",
  },
  openGraph: {
    title: "DealGo — Di chuyển thông minh, Ẩm thực linh hoạt",
    description: "Tự do Deal giá cùng DealGo. Ghép xe 2 phút, hàng ngàn quán ngon quanh bạn.",
    url: "https://dealgo.vn",
    siteName: "DealGo",
    locale: "vi_VN",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="vi" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              try {
                const theme = localStorage.getItem('dealgo_theme');
                const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                if (theme === 'dark' || (!theme && prefersDark)) {
                  document.documentElement.classList.add('dark');
                  document.documentElement.setAttribute('data-theme', 'dark');
                } else {
                  document.documentElement.classList.remove('dark');
                  document.documentElement.setAttribute('data-theme', 'light');
                }
              } catch (_) {}
            `,
          }}
        />
      </head>
      <body className="min-h-screen bg-[var(--color-canvas)] text-[var(--color-ink)] antialiased">
        {children}
      </body>
    </html>
  );
}
