"use client";

import { useState } from "react";
import Link from "next/link";
import { ThemeToggle } from "./theme-toggle";
import { BrandMark } from "./brand-mark";

export function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 w-full glass-panel border-b border-[var(--color-border)] transition-all">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center transition-transform hover:scale-102">
          <BrandMark size="md" showWordmark={true} />
        </Link>


        {/* Desktop Navigation Links */}
        <nav className="hidden items-center gap-7 md:flex">
          <a
            href="#services"
            className="text-sm font-medium text-[var(--color-muted)] transition-colors hover:text-[var(--color-brand)]"
          >
            Dịch vụ
          </a>
          <a
            href="#deal-feature"
            className="flex items-center gap-1.5 text-sm font-medium text-[var(--color-muted)] transition-colors hover:text-[var(--color-brand)]"
          >
            <span>Deal Giá</span>
            <span className="rounded-full bg-orange-500/10 px-1.5 py-0.2 text-[10px] font-bold text-orange-500">HOT</span>
          </a>
          <a
            href="#partners"
            className="text-sm font-medium text-[var(--color-muted)] transition-colors hover:text-[var(--color-brand)]"
          >
            Dành cho Đối tác
          </a>
          <a
            href="#faq"
            className="text-sm font-medium text-[var(--color-muted)] transition-colors hover:text-[var(--color-brand)]"
          >
            Hỏi đáp
          </a>
        </nav>

        {/* Desktop Action Buttons */}
        <div className="hidden items-center gap-3 md:flex">
          <ThemeToggle />
          <a
            href="#download"
            className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-brand)] px-4 py-2 text-xs font-semibold text-white shadow-md shadow-purple-600/25 transition-all hover:bg-[var(--color-brand-dark)] hover:shadow-lg active:scale-98"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Tải ứng dụng
          </a>
        </div>

        {/* Mobile Hamburger Button */}
        <div className="flex items-center gap-2 md:hidden">
          <ThemeToggle />
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-[var(--color-border)] bg-[var(--color-canvas)] text-[var(--color-ink)]"
            aria-label="Toggle menu"
          >
            {mobileMenuOpen ? (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            ) : (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Mobile Drawer Menu */}
      {mobileMenuOpen && (
        <div className="border-b border-[var(--color-border)] bg-[var(--color-canvas)] px-4 pt-2 pb-5 md:hidden">
          <div className="flex flex-col space-y-3">
            <a
              href="#services"
              onClick={() => setMobileMenuOpen(false)}
              className="rounded-lg px-3 py-2 text-sm font-medium text-[var(--color-ink)] hover:bg-[var(--color-border)]/50"
            >
              Dịch vụ
            </a>
            <a
              href="#deal-feature"
              onClick={() => setMobileMenuOpen(false)}
              className="flex items-center justify-between rounded-lg px-3 py-2 text-sm font-medium text-[var(--color-ink)] hover:bg-[var(--color-border)]/50"
            >
              <span>Tính năng Deal Giá</span>
              <span className="rounded-full bg-orange-500/10 px-2 py-0.5 text-xs font-bold text-orange-500">Mới</span>
            </a>
            <a
              href="#partners"
              onClick={() => setMobileMenuOpen(false)}
              className="rounded-lg px-3 py-2 text-sm font-medium text-[var(--color-ink)] hover:bg-[var(--color-border)]/50"
            >
              Dành cho Đối tác
            </a>
            <a
              href="#faq"
              onClick={() => setMobileMenuOpen(false)}
              className="rounded-lg px-3 py-2 text-sm font-medium text-[var(--color-ink)] hover:bg-[var(--color-border)]/50"
            >
              Hỏi đáp & Hỗ trợ
            </a>
            <div className="pt-2 flex flex-col gap-2">
              <a
                href="#download"
                onClick={() => setMobileMenuOpen(false)}
                className="flex items-center justify-center gap-2 rounded-xl bg-[var(--color-brand)] py-2.5 text-sm font-semibold text-white shadow-md"
              >
                Tải ứng dụng DealGo
              </a>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
