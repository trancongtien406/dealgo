"use client";

import { useState } from "react";
import Image from "next/image";
import { BrandMark } from "./brand-mark";

export function HeroSection() {
  const [dealPrice, setDealPrice] = useState(35000);

  return (
    <section className="relative overflow-hidden pt-12 pb-20 md:pt-16 md:pb-28 bg-mesh-gradient">
      {/* Background Decorative Blur Orbs */}
      <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 h-96 w-96 -translate-x-1/2 rounded-full bg-purple-500/15 blur-3xl" />
      <div className="pointer-events-none absolute top-1/3 -right-20 -z-10 h-80 w-80 rounded-full bg-emerald-500/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-10 -left-20 -z-10 h-80 w-80 rounded-full bg-orange-500/10 blur-3xl" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid items-center gap-12 lg:grid-cols-12 lg:gap-8">
          {/* Left Column: Headlines & Call to Actions */}
          <div className="lg:col-span-7 text-center lg:text-left">
            {/* Pill Badge */}
            <div className="inline-flex items-center gap-2 rounded-full border border-[var(--color-border)] bg-[var(--color-canvas)]/80 px-4 py-1.5 text-xs font-semibold shadow-sm backdrop-blur-md">
              <span className="flex h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
              <span className="text-[var(--color-ink)]">Nền tảng công nghệ Di chuyển &amp; Ẩm thực</span>
              <span className="font-extrabold">
                <span className="text-[var(--color-brand)]">Deal</span>
                <span className="text-[var(--color-success)]">Go</span>
              </span>
            </div>

            {/* Main Headline */}
            <h1 className="mt-6 text-4xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-5xl md:text-6xl leading-tight">
              Di chuyển thông minh,{" "}
              <span className="text-[var(--color-brand)]">Ẩm thực linh hoạt</span> cùng{" "}
              <span className="whitespace-nowrap">
                <span className="text-[var(--color-brand)]">Deal</span>
                <span className="text-[var(--color-success)]">Go</span>.
              </span>
            </h1>

            {/* Subheadline */}
            <p className="mt-6 text-base text-[var(--color-muted)] sm:text-lg lg:max-w-xl leading-relaxed">
              Trải nghiệm gọi xe hai bánh và đặt đồ ăn nhanh chóng. DealGo trao quyền cho khách hàng và tài xế tự do thương lượng mức giá công bằng, minh bạch — không lo phí giờ cao điểm vô lý!
            </p>

            {/* CTA Group */}
            <div className="mt-8 flex flex-col gap-3.5 sm:flex-row sm:justify-center lg:justify-start">
              <a
                href="#download"
                className="inline-flex items-center justify-center gap-2.5 rounded-2xl bg-[var(--color-brand)] px-6 py-3.5 text-sm font-bold text-white shadow-lg shadow-purple-600/30 transition-all hover:bg-[var(--color-brand-dark)] hover:shadow-xl active:scale-98"
              >
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                </svg>
                Tải ứng dụng ngay
              </a>
              <a
                href="#partners"
                className="inline-flex items-center justify-center gap-2 rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] px-6 py-3.5 text-sm font-semibold text-[var(--color-ink)] transition-colors hover:border-[var(--color-brand)] hover:text-[var(--color-brand)] shadow-sm"
              >
                Trở thành Đối tác DealGo
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
                </svg>
              </a>
            </div>

            {/* Trust Metrics Bar */}
            <div className="mt-10 grid grid-cols-3 gap-4 border-t border-[var(--color-border)] pt-6 text-left">
              <div>
                <p className="text-2xl font-black text-[var(--color-brand)] sm:text-3xl">2 Phút</p>
                <p className="text-xs text-[var(--color-muted)]">Ghép xe siêu tốc</p>
              </div>
              <div>
                <p className="text-2xl font-black text-[var(--color-success)] sm:text-3xl">100%</p>
                <p className="text-xs text-[var(--color-muted)]">Giá rõ ràng minh bạch</p>
              </div>
              <div>
                <p className="text-2xl font-black text-[var(--color-food)] sm:text-3xl">4.9/5 ★</p>
                <p className="text-xs text-[var(--color-muted)]">Đánh giá hài lòng</p>
              </div>
            </div>
          </div>

          {/* Right Column: Interactive App Simulation Mockup */}
          <div className="lg:col-span-5 flex justify-center">
            <div className="relative w-full max-w-sm">
              {/* Floating Benefit Tag 1 with Real Driver Avatar */}
              <div className="animate-float absolute -top-5 -left-8 z-20 flex items-center gap-2.5 rounded-2xl glass-panel p-2.5 shadow-xl border border-[var(--color-border)]">
                <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-purple-500/10 overflow-hidden border border-purple-500/20">
                  <img src="/assets/images/role_driver.png" alt="Tài xế DealGo" className="h-full w-full object-cover" />
                </div>
                <div>
                  <p className="text-xs font-bold text-[var(--color-ink)]">Tài xế đang tới đón</p>
                  <p className="text-[10px] text-[var(--color-muted)]">Nguyễn Văn A • 2 phút nữa</p>
                </div>
              </div>

              {/* Floating Benefit Tag 2 with Real Scooter Image */}
              <div className="animate-float absolute -bottom-6 -right-6 z-20 flex items-center gap-2.5 rounded-2xl glass-panel p-2.5 shadow-xl border border-[var(--color-border)]" style={{ animationDelay: "1.5s" }}>
                <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-emerald-500/10 p-1 border border-emerald-500/20">
                  <img src="/assets/images/vehicle_scooter_white.png" alt="Xe DealGo" className="h-full w-full object-contain" />
                </div>
                <div>
                  <p className="text-xs font-bold text-[var(--color-ink)]">Deal giá thành công!</p>
                  <p className="text-[10px] text-emerald-600 font-semibold">35.000 đ • Đón tại ngõ</p>
                </div>
              </div>


              {/* Phone Frame */}
              <div className="relative rounded-[40px] border-4 border-slate-800 bg-slate-950 p-3 shadow-2xl ring-1 ring-slate-800/50">
                {/* Phone Speaker Notch */}
                <div className="mx-auto mb-2 h-4 w-28 rounded-full bg-slate-800" />

                {/* Inner Screen */}
                <div className="overflow-hidden rounded-[32px] bg-[var(--color-canvas)] p-4 text-[var(--color-ink)]">
                  {/* Top Status */}
                  <div className="flex items-center justify-between text-xs pb-1 border-b border-[var(--color-border)]/50">
                    <BrandMark size="sm" showWordmark={true} />
                    <span className="flex items-center gap-1 text-emerald-600 font-medium text-[10px]">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                      Trực tuyến
                    </span>
                  </div>

                  {/* Route Card */}
                  <div className="mt-3 rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-3 shadow-xs">
                    <div className="flex items-start gap-2.5">
                      <div className="mt-1 flex flex-col items-center gap-1">
                        <div className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
                        <div className="h-6 w-0.5 border-l border-dashed border-slate-300 dark:border-slate-700" />
                        <div className="h-2.5 w-2.5 rounded-full bg-rose-500" />
                      </div>
                      <div className="flex-1 space-y-2">
                        <div>
                          <p className="text-[10px] text-[var(--color-muted)]">Điểm đón</p>
                          <p className="text-xs font-semibold">120 Nguyễn Văn Linh, Hải Châu</p>
                        </div>
                        <div>
                          <p className="text-[10px] text-[var(--color-muted)]">Điểm đến</p>
                          <p className="text-xs font-semibold">Bãi biển Mỹ Khê, Sơn Trà</p>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Interactive Deal Box */}
                  <div className="mt-3.5 rounded-2xl border border-purple-200 bg-purple-50/70 p-3.5 dark:border-purple-900/40 dark:bg-purple-950/30">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-[var(--color-brand)]">Tính năng Deal Giá</span>
                      <span className="rounded-md bg-purple-200/80 px-1.5 py-0.5 text-[10px] font-bold text-purple-800 dark:bg-purple-800/40 dark:text-purple-300">
                        Thương lượng 1:1
                      </span>
                    </div>

                    <div className="mt-2.5 flex items-center justify-between rounded-xl bg-white p-2.5 shadow-xs dark:bg-slate-900">
                      <div>
                        <p className="text-[10px] text-[var(--color-muted)]">Giá bạn đề xuất</p>
                        <p className="text-base font-extrabold text-[var(--color-brand)]">
                          {dealPrice.toLocaleString("vi-VN")} đ
                        </p>
                      </div>
                      <div className="flex gap-1">
                        <button
                          onClick={() => setDealPrice(Math.max(25000, dealPrice - 3000))}
                          className="flex h-7 w-7 items-center justify-center rounded-lg border border-slate-200 bg-slate-50 text-xs font-bold hover:bg-slate-100 dark:border-slate-800 dark:bg-slate-800"
                        >
                          -
                        </button>
                        <button
                          onClick={() => setDealPrice(dealPrice + 3000)}
                          className="flex h-7 w-7 items-center justify-center rounded-lg border border-slate-200 bg-slate-50 text-xs font-bold hover:bg-slate-100 dark:border-slate-800 dark:bg-slate-800"
                        >
                          +
                        </button>
                      </div>
                    </div>

                    {/* Driver Response simulation */}
                    <div className="mt-2.5 flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50/70 p-2 text-xs dark:border-emerald-900/40 dark:bg-emerald-950/40">
                      <div className="flex h-6 w-6 items-center justify-center rounded-full bg-emerald-500 text-white font-bold text-[10px]">
                        TX
                      </div>
                      <div className="flex-1">
                        <p className="text-[11px] font-bold text-emerald-800 dark:text-emerald-300">
                          Tài xế Nguyễn Văn A nhận deal!
                        </p>
                        <p className="text-[10px] text-emerald-700/80 dark:text-emerald-400">
                          Cách bạn 350m • Đón ngay sau 2 phút
                        </p>
                      </div>
                    </div>
                  </div>

                  {/* Accept CTA Button */}
                  <button className="mt-4 w-full rounded-xl bg-[var(--color-brand)] py-2.5 text-xs font-bold text-white shadow-md shadow-purple-600/30 transition-all hover:bg-[var(--color-brand-dark)]">
                    Xác nhận chuyến xe ngay
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
