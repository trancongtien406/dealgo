import type { Metadata } from "next";
import { Inter } from "next/font/google";
import type { ReactNode } from "react";
import { AppProviders } from "@/lib/query/provider";
import "./globals.css";

const inter = Inter({
  subsets: ["latin", "vietnamese"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "DealGo Quản trị",
  description: "Kênh vận hành nội bộ DealGo cho Ride và Food.",
  icons: {
    icon: [
      { url: "/icon.svg", type: "image/svg+xml" },
      { url: "/dealgo-icon.svg", type: "image/svg+xml" },
    ],
  },
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
        <script
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
