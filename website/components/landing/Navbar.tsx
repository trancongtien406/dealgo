"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { ThemeToggle } from "@/components/theme/theme-toggle";

const navLinks = [
  { label: "Dịch vụ", href: "#dich-vu" },
  { label: "Cách hoạt động", href: "#cach-hoat-dong" },
  { label: "Đối tác", href: "#doi-tac" },
  { label: "An toàn", href: "#an-toan" },
  { label: "Hỗ trợ", href: "#faq" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 15);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      id="navbar"
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "bg-white/95 backdrop-blur-md shadow-sm border-b border-gray-100"
          : "bg-white/70 backdrop-blur-sm"
      }`}
    >
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        <div className="flex items-center justify-between h-20">
          {/* Logo */}
          <Link href="/" className="flex flex-col justify-center select-none group">
            <div className="flex items-center text-3xl font-black tracking-tight leading-none">
              <span className="text-[#6D28D9]">Deal</span>
              <span className="text-[#00D06C]">Go</span>
            </div>
            <span className="text-[11px] text-gray-500 font-medium tracking-normal mt-0.5">
              Giá do bạn chọn · Trọn gói hành trình
            </span>
          </Link>

          {/* Desktop Nav Links */}
          <nav className="hidden lg:flex items-center gap-7">
            {navLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="text-[15px] font-medium text-gray-700 hover:text-[#5B21B6] transition-colors duration-200"
              >
                {link.label}
              </a>
            ))}
          </nav>

          {/* Right Action: coverage link only (Login/Register removed as requested) */}
          <div className="hidden lg:flex items-center gap-3">
            <ThemeToggle />
            <a
              href="#khu-vuc"
              className="flex items-center gap-2 text-sm font-semibold text-gray-800 bg-white/90 hover:bg-white border border-gray-200/90 rounded-xl px-4 py-2 shadow-sm transition-all duration-200 hover:border-purple-300 hover:shadow"
            >
              <svg className="w-4 h-4 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 110-5 2.5 2.5 0 010 5z" />
              </svg>
              <span>Toàn quốc</span>
            </a>
          </div>

          {/* Mobile Menu Button */}
          <div className="flex items-center gap-2 lg:hidden">
            <ThemeToggle compact className="size-9" />
            {/* Mobile coverage link */}
            <a
              href="#khu-vuc"
              className="flex items-center gap-1 text-xs font-semibold text-gray-700 bg-white border border-gray-200 rounded-full px-3 py-1.5 shadow-sm"
            >
              <svg className="w-3.5 h-3.5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 110-5 2.5 2.5 0 010 5z" />
              </svg>
              Toàn quốc
            </a>

            <button
              onClick={() => setMobileOpen(!mobileOpen)}
              className="p-2 rounded-xl text-gray-700 hover:bg-gray-100 transition-colors"
              aria-label="Toggle menu"
            >
              {mobileOpen ? (
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              ) : (
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              )}
            </button>
          </div>
        </div>

        {/* Mobile Menu Drawer */}
        {mobileOpen && (
          <div className="lg:hidden border-t border-gray-100 py-4 bg-white/95 backdrop-blur-md rounded-b-2xl shadow-lg space-y-1 px-2">
            {navLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={() => setMobileOpen(false)}
                className="block px-4 py-2.5 text-base font-medium text-gray-700 hover:text-[#5B21B6] hover:bg-purple-50 rounded-xl transition-all"
              >
                {link.label}
              </a>
            ))}
          </div>
        )}
      </div>
    </header>
  );
}
