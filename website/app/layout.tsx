import type { Metadata } from "next";
import { Inter } from "next/font/google";
import Script from "next/script";
import type { ReactNode } from "react";
import { AppProviders } from "@/lib/query/provider";
import { SITE_NAME, siteUrl } from "@/lib/seo/site";
import "./globals.css";

const inter = Inter({
  subsets: ["latin", "vietnamese"],
  variable: "--font-inter",
});

// Default is noindex: admin, login and share pages inherit it. Public pages
// (landing, support, terms, privacy) opt in to indexing themselves.
export const metadata: Metadata = {
  metadataBase: siteUrl(),
  title: { default: "DealGo Quản trị", template: "%s | DealGo" },
  description: "Kênh vận hành nội bộ DealGo cho Ride và Food.",
  applicationName: SITE_NAME,
  icons: { icon: "/icon.svg", apple: "/apple-icon.png" },
  robots: {
    index: false,
    follow: false,
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="vi"
      suppressHydrationWarning
      className={`${inter.variable} h-full antialiased`}
    >
      <head>
        <Script
          id="dealgo-theme-init"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('dealgo-theme');var p=window.matchMedia('(prefers-color-scheme: dark)').matches;var r=(t==='dark'||t==='light')?t:(p?'dark':'light');if(r==='dark'){document.documentElement.classList.add('dark');document.documentElement.setAttribute('data-theme','dark');}else{document.documentElement.classList.remove('dark');document.documentElement.setAttribute('data-theme','light');}}catch(e){}})()`,
          }}
        />
      </head>
      <body className="min-h-full bg-canvas font-sans text-ink">
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
