import Image from "next/image";
import { BrandMark } from "./brand-mark";

export function AppDownloadSection() {
  return (
    <section id="download" className="py-20 sm:py-28 relative overflow-hidden bg-mesh-gradient">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="relative rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-8 sm:p-14 lg:p-16 shadow-2xl overflow-hidden">
          {/* Subtle background glow */}
          <div className="pointer-events-none absolute -top-24 -right-24 h-96 w-96 rounded-full bg-purple-500/15 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-24 -left-24 h-96 w-96 rounded-full bg-emerald-500/10 blur-3xl" />

          <div className="grid items-center gap-10 lg:grid-cols-12">
            {/* Left Column: Text & Download CTAs */}
            <div className="lg:col-span-7">
              <span className="inline-flex items-center gap-2 rounded-full bg-emerald-500/10 px-3.5 py-1 text-xs font-bold text-emerald-600 dark:text-emerald-400">
                <span>📱</span>
                <span>Một ứng dụng đa vai trò — Khách / Tài xế / Quán</span>
              </span>

              <h2 className="mt-4 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl md:text-5xl leading-tight">
                Trải nghiệm{" "}
                <span className="whitespace-nowrap">
                  <span className="text-[var(--color-brand)]">Deal</span>
                  <span className="text-[var(--color-success)]">Go</span>
                </span>{" "}
                ngay trên điện thoại của bạn
              </h2>

              <p className="mt-4 text-sm text-[var(--color-muted)] sm:text-base leading-relaxed">
                Tất cả trong một: Khách hàng đặt xe &amp; món ngon, Tài xế nhận cuốc tăng thu nhập, Chủ quán quản lý thực đơn tức thì. Tải app miễn phí trên cả hai nền tảng iOS và Android.
              </p>

              {/* QR Code & Badges Container */}
              <div className="mt-8 flex flex-col gap-6 sm:flex-row sm:items-center">
                {/* QR Box with Official App Icon in Center */}
                <div className="flex items-center gap-3.5 rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-3.5 shadow-xs">
                  <div className="relative flex h-20 w-20 shrink-0 items-center justify-center rounded-xl bg-white p-1.5 shadow-xs border border-slate-200">
                    <svg viewBox="0 0 100 100" className="h-full w-full fill-slate-900">
                      <rect x="0" y="0" width="30" height="30" rx="4" />
                      <rect x="5" y="5" width="20" height="20" fill="white" rx="2" />
                      <rect x="9" y="9" width="12" height="12" rx="2" />
                      
                      <rect x="70" y="0" width="30" height="30" rx="4" />
                      <rect x="75" y="5" width="20" height="20" fill="white" rx="2" />
                      <rect x="79" y="9" width="12" height="12" rx="2" />

                      <rect x="0" y="70" width="30" height="30" rx="4" />
                      <rect x="5" y="75" width="20" height="20" fill="white" rx="2" />
                      <rect x="9" y="79" width="12" height="12" rx="2" />

                      <rect x="40" y="10" width="10" height="10" />
                      <rect x="55" y="20" width="10" height="10" />
                      <rect x="35" y="45" width="20" height="15" rx="2" />
                      <rect x="70" y="45" width="15" height="15" />
                      <rect x="40" y="75" width="10" height="15" />
                      <rect x="65" y="75" width="20" height="20" rx="2" />
                    </svg>

                    {/* Official Icon Overlay in Center of QR */}
                    <div className="absolute inset-0 flex items-center justify-center">
                      <div className="h-6 w-6 rounded-md bg-white p-0.5 shadow-xs">
                        <img src="/dealgo-icon.svg" alt="DealGo Icon" className="h-full w-full object-contain" />
                      </div>
                    </div>
                  </div>
                  <div>
                    <p className="text-xs font-bold text-[var(--color-ink)]">Quét mã tải app</p>
                    <p className="mt-0.5 text-[10px] text-[var(--color-muted)]">Camera điện thoại tự nhận diện</p>
                    <span className="mt-1 inline-block text-[10px] font-bold text-[var(--color-brand)]">iOS &amp; Android</span>
                  </div>
                </div>

                {/* App Store / Google Play Buttons */}
                <div className="flex flex-col gap-2.5">
                  <a
                    href="#download"
                    className="flex items-center gap-3 rounded-2xl bg-slate-900 px-5 py-2.5 text-white transition-transform hover:scale-102 active:scale-98 dark:bg-slate-800"
                  >
                    <svg className="h-6 w-6 fill-current" viewBox="0 0 24 24">
                      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.79 1.08-1.89.96-3-.99.04-2.16.67-2.84 1.48-.59.7-.96 1.77-.85 2.84 1.11.08 2.19-.57 2.73-1.32z" />
                    </svg>
                    <div className="text-left">
                      <p className="text-[10px] leading-none text-slate-400">Tải về trên</p>
                      <p className="text-xs font-bold leading-tight">App Store</p>
                    </div>
                  </a>

                  <a
                    href="#download"
                    className="flex items-center gap-3 rounded-2xl bg-slate-900 px-5 py-2.5 text-white transition-transform hover:scale-102 active:scale-98 dark:bg-slate-800"
                  >
                    <svg className="h-6 w-6 fill-current" viewBox="0 0 24 24">
                      <path d="M3.609 1.814L13.792 12 3.61 22.186a2.44 2.44 0 0 1-.61-.71 2.4 2.4 0 0 1-.29-1.2V3.724c0-.447.1-.86.29-1.2.163-.284.37-.53.609-.71zm1.258-.87a2.535 2.535 0 0 1 1.716-.168l11.02 6.297L15.11 9.56 4.867.944zm11.02 15.776L4.867 23.056l10.244-8.616 2.492 2.492-2.716 1.788zm1.905-1.087l3.228-1.844c1.233-.705 1.233-1.85 0-2.555l-3.228-1.844-2.22 2.22 2.22 2.223z" />
                    </svg>
                    <div className="text-left">
                      <p className="text-[10px] leading-none text-slate-400">Có sẵn trên</p>
                      <p className="text-xs font-bold leading-tight">Google Play</p>
                    </div>
                  </a>
                </div>
              </div>
            </div>

            {/* Right Column: Visual Mockup Illustration with Real Assets */}
            <div className="lg:col-span-5 flex justify-center">
              <div className="w-full max-w-sm rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5 shadow-lg space-y-3.5">
                {/* Official Brand Header inside card */}
                <div className="flex items-center justify-between pb-3 border-b border-[var(--color-border)]">
                  <BrandMark size="sm" showWordmark={true} />
                  <span className="text-[10px] font-semibold text-[var(--color-muted)]">Phiên bản 1.0.0</span>
                </div>

                {/* Ride Card with official styling */}
                <div className="flex items-center gap-3 rounded-2xl bg-[var(--color-canvas-card)] p-3 shadow-xs border border-[var(--color-border)]">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-purple-500/10 p-1">
                    <img src="/dealgo-icon.svg" alt="DealGo Ride" className="h-full w-full object-contain" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-[var(--color-ink)] truncate">
                      <span className="text-[var(--color-brand)]">Deal</span>
                      <span className="text-[var(--color-success)]">Go</span> Ride
                    </p>
                    <p className="text-[10px] text-[var(--color-muted)] truncate">Đà Nẵng: Cầu Rồng → Bán đảo Sơn Trà</p>
                  </div>
                  <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-bold text-emerald-600">
                    35.000 đ
                  </span>
                </div>

                {/* Food Card with official styling */}
                <div className="flex items-center gap-3 rounded-2xl bg-[var(--color-canvas-card)] p-3 shadow-xs border border-[var(--color-border)]">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-orange-500/10 overflow-hidden">
                    <img src="/assets/images/food_mi_quang.png" alt="Món ăn" className="h-full w-full object-cover" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-[var(--color-ink)] truncate">
                      <span className="text-[var(--color-brand)]">Deal</span>
                      <span className="text-[var(--color-success)]">Go</span> Food
                    </p>
                    <p className="text-[10px] text-[var(--color-muted)] truncate">Mì Quảng Ếch Bếp Trang • Đang giao</p>
                  </div>
                  <span className="rounded-full bg-orange-500/10 px-2 py-0.5 text-[10px] font-bold text-orange-600">
                    12 phút
                  </span>
                </div>

                {/* Delivery Voucher Card */}
                <div className="flex items-center gap-3 rounded-2xl bg-[var(--color-canvas-card)] p-3 shadow-xs border border-[var(--color-border)]">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-blue-500/10 text-xl font-bold">
                    🎁
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-[var(--color-ink)] truncate">Ưu đãi chuyến đầu 50%</p>
                    <p className="text-[10px] text-[var(--color-muted)] truncate">Nhập mã: DEALGOFIRST</p>
                  </div>
                  <span className="rounded-full bg-blue-500/10 px-2 py-0.5 text-[10px] font-bold text-blue-600">
                    Áp dụng
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
