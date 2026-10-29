import Image from "next/image";
import type { PublicSiteConfig } from "@/features/site-config/types";
import StoreBadges from "./StoreBadges";

export default function HeroSection({ siteConfig = {} }: { siteConfig?: PublicSiteConfig }) {
  const features = [
    {
      icon: (
        <svg className="w-5 h-5 sm:w-6 sm:h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
        </svg>
      ),
      title: "Chủ động thương lượng giá",
      desc: "Đặt xe với mức giá phù hợp",
    },
    {
      icon: (
        <svg className="w-5 h-5 sm:w-6 sm:h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <rect x="5" y="2" width="14" height="20" rx="3" />
          <line x1="12" y1="18" x2="12.01" y2="18" strokeWidth={3} strokeLinecap="round" />
        </svg>
      ),
      title: "Một ứng dụng, ba vai trò",
      desc: "Khách hàng, quán ăn và tài xế",
    },
    {
      icon: (
        <svg className="w-5 h-5 sm:w-6 sm:h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <polyline points="12 6 12 12 16 14" />
        </svg>
      ),
      title: "Theo dõi minh bạch",
      desc: "Biết rõ hành trình và trạng thái đơn",
    },
    {
      icon: (
        <svg className="w-5 h-5 sm:w-6 sm:h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M3 18v-6a9 9 0 0118 0v6" />
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 19a2 2 0 01-2 2h-1a2 2 0 01-2-2v-3a2 2 0 012-2h3zM3 19a2 2 0 002 2h1a2 2 0 002-2v-3a2 2 0 00-2-2H3z" />
        </svg>
      ),
      title: "Chat và gọi trong ứng dụng",
      desc: "Liên lạc với tài xế, quán theo từng đơn",
    },
  ];

  return (
    <section
      id="hero"
      className="relative min-h-screen lg:h-[100vh] lg:max-h-[960px] flex flex-col justify-between overflow-hidden pt-20 pb-3 sm:pb-5 bg-[#F8F7FF]"
    >
      {/* Background Da Nang Bridge Landscape */}
      <div className="absolute inset-0 z-0">
        <Image
          src="/landing/danang_bridge.jpg"
          alt="Cầu Rồng Đà Nẵng nhìn từ bờ sông Hàn"
          fill
          className="object-cover object-[85%_center] md:object-right"
          priority
          sizes="100vw"
        />
        {/* Sweeping organic gradient overlay matching reference image */}
        <div className="absolute inset-0 bg-gradient-to-r from-[#F6F4FE] via-[#F6F4FE]/95 md:via-[#F6F4FE]/75 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#F8F7FF] via-transparent to-transparent opacity-85" />
      </div>

      {/* Decorative smooth curved wave in the background on the left */}
      <div className="absolute -bottom-10 -left-20 w-[680px] h-[580px] bg-gradient-to-tr from-white/90 via-purple-100/40 to-transparent rounded-[120px] blur-2xl pointer-events-none" />

      {/* Main Content Area */}
      <div className="relative z-10 max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12 w-full pt-1 pb-1 flex-1 flex items-center">
        <div className="grid lg:grid-cols-12 gap-6 lg:gap-8 items-center w-full">
          {/* Left Column (7 cols on lg) */}
          <div className="lg:col-span-7 space-y-4 sm:space-y-5">
            {/* Top Badge: Pill Bo góc tròn mềm */}
            <div className="inline-flex items-center gap-2 bg-[#EDE9FE]/95 border border-[#DDD6FE] rounded-full px-4 py-1.5 shadow-sm">
              <svg className="w-4 h-4 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z" />
              </svg>
              <span className="text-xs sm:text-sm font-semibold text-[#6D28D9]">
                Đặt xe · Đồ ăn · Thương lượng giá
              </span>
            </div>

            {/* Headline with 4 lines matching exact reference */}
            <h1 className="space-y-0.5 font-black tracking-tight leading-[1.08] select-none">
              <span className="block text-4xl sm:text-5xl lg:text-[52px] text-[#0F172A]">
                Đi muôn nơi,
              </span>
              <span className="block text-4xl sm:text-5xl lg:text-[52px] text-[#6D28D9]">
                Mua vạn món
              </span>
              <span className="block text-4xl sm:text-5xl lg:text-[52px] text-[#0F172A]">
                Chủ động cùng
              </span>
              <span className="block text-4xl sm:text-5xl lg:text-[52px] text-[#00D06C]">
                DealGo
              </span>
            </h1>

            {/* Subtitle / Description */}
            <p className="text-sm sm:text-base text-gray-600 leading-relaxed max-w-xl font-normal">
              Đặt xe máy hoặc ô tô với mức giá bạn đề xuất và thương lượng trực tiếp với tài xế, đặt món từ quán ăn, cửa hàng gần bạn — tất cả trong một ứng dụng, phục vụ tại Đà Nẵng.
            </p>

            {/* CTA Buttons: Màu tím DealGo chuẩn #6D28D9 */}
            <div className="flex flex-wrap items-center gap-3.5 pt-1">
              <a
                href="#tai-ung-dung"
                className="inline-flex items-center gap-2 bg-[#6D28D9] hover:bg-[#581C87] text-white font-semibold text-[14px] sm:text-[15px] px-6 sm:px-7 py-3 sm:py-3.5 rounded-2xl shadow-lg shadow-purple-600/30 transition-all duration-200 transform hover:-translate-y-0.5 active:translate-y-0"
              >
                <span>Bắt đầu với DealGo</span>
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M14 5l7 7m0 0l-7 7m7-7H3" />
                </svg>
              </a>

              <a
                href="#cach-hoat-dong"
                className="inline-flex items-center gap-2.5 bg-white/95 hover:bg-purple-50/80 text-[#6D28D9] border-2 border-[#6D28D9]/25 hover:border-[#6D28D9]/40 font-semibold text-[14px] sm:text-[15px] px-5 sm:px-6 py-3 sm:py-3.5 rounded-2xl shadow-sm hover:shadow transition-all duration-200"
              >
                <svg className="w-4 h-4 sm:w-5 sm:h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                  <circle cx="12" cy="12" r="10" />
                  <polygon points="10 8 16 12 10 16" fill="currentColor" stroke="none" />
                </svg>
                <span>Xem cách hoạt động</span>
              </a>
            </div>

            {/* Store links come from admin Website settings; hidden until set. */}
            <StoreBadges config={siteConfig} />
          </div>

          {/* Right Column: Realistic iPhone Mockup in 3D (Solid Opaque Screen with Clean Cutout & Accurate Scale) */}
          <div
            className="lg:col-span-5 relative flex items-center justify-center overflow-visible"
            style={{ perspective: "1200px" }}
          >
            {/* Soft Ambient Purple Glow behind phone */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[380px] h-[380px] bg-purple-400/20 rounded-full blur-3xl pointer-events-none" />

            {/* 3D Phone & Overlays Container */}
            <div
              className="relative animate-float-phone"
              style={{
                transformStyle: "preserve-3d",
              }}
            >
              {/* Handwritten Calligraphy Accent: "Đà Nẵng gì đâu cũng gần ♡" */}
              <div
                className="absolute -top-10 -right-4 sm:-right-10 z-40 text-[#6D28D9] select-none pointer-events-none transform -rotate-6 hidden sm:block whitespace-nowrap"
                style={{
                  fontFamily: "var(--font-caveat), cursive",
                  fontSize: "25px",
                  fontWeight: 700,
                  textShadow: "0 2px 10px rgba(109, 40, 217, 0.12)",
                }}
              >
                Đà Nẵng đi đâu cũng gần ♡
              </div>
              {/* Floating Card 1: "Đặt xe linh hoạt" - Ẩn trên màn hình rất nhỏ, hiện từ sm+ */}
              <div
                className="hidden sm:flex absolute right-[calc(100%-42px)] top-[16%] z-30 bg-white/95 backdrop-blur-md rounded-[28px] py-2 px-3 sm:py-2.5 sm:px-3.5 shadow-[0_16px_36px_rgba(109,40,217,0.18),0_4px_12px_rgba(0,0,0,0.06)] border border-white items-center gap-2.5 transition-transform hover:scale-105 duration-200 select-none animate-float"
                style={{
                  transform: "translateZ(60px)",
                }}
              >
                <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-full bg-gradient-to-br from-[#7C3AED] to-[#6D28D9] flex items-center justify-center flex-shrink-0 shadow-md">
                  {/* Car Icon */}
                  <svg className="w-4 h-4 sm:w-5 sm:h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                  </svg>
                </div>
                <div className="pr-1">
                  <div className="text-xs sm:text-[13px] font-bold text-gray-900 leading-tight whitespace-nowrap">
                    Đặt xe linh hoạt
                  </div>
                  <div className="text-[10px] sm:text-[11px] text-gray-500 leading-tight mt-0.5 whitespace-nowrap">
                    Chủ động đề xuất giá
                  </div>
                </div>
                <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-gray-100 flex items-center justify-center text-gray-600 text-[10px] sm:text-xs font-bold shadow-xs">
                  →
                </div>
              </div>

              {/* Floating Card 2: "Đồ ăn phong phú" - Ẩn trên màn hình rất nhỏ, hiện từ sm+ */}
              <div
                className="hidden sm:flex absolute left-[calc(100%-42px)] top-[36%] z-30 bg-white/95 backdrop-blur-md rounded-[28px] py-2 px-3 sm:py-2.5 sm:px-3.5 shadow-[0_16px_36px_rgba(0,208,108,0.2),0_4px_12px_rgba(0,0,0,0.06)] border border-white items-center gap-2.5 transition-transform hover:scale-105 duration-200 select-none animate-float-delayed"
                style={{
                  transform: "translateZ(60px)",
                }}
              >
                <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-full bg-gradient-to-br from-[#00D06C] to-[#059669] flex items-center justify-center flex-shrink-0 shadow-md">
                  {/* Food Bag Icon */}
                  <svg className="w-4 h-4 sm:w-5 sm:h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-1.99.9-1.99 2L3 20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm0 10c-2.76 0-5-2.24-5-5h2c0 1.66 1.34 3 3 3s3-1.34 3-3h2c0 2.76-2.24 5-5 5z" />
                  </svg>
                </div>
                <div className="pr-1">
                  <div className="text-xs sm:text-[13px] font-bold text-gray-900 leading-tight whitespace-nowrap">
                    Đồ ăn phong phú
                  </div>
                  <div className="text-[10px] sm:text-[11px] text-gray-500 leading-tight mt-0.5 whitespace-nowrap">
                    Giao tận nơi nhanh chóng
                  </div>
                </div>
                <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-gray-100 flex items-center justify-center text-gray-600 text-[10px] sm:text-xs font-bold shadow-xs">
                  →
                </div>
              </div>

              {/* iPhone Mockup (Hiển thị 100% trọn vẹn toàn bộ máy từ đầu đến chân với cằm bo tròn đầy đủ) */}
              <div className="relative w-[300px] sm:w-[325px] lg:w-[340px] h-[545px] sm:h-[590px] lg:h-[618px] select-none filter drop-shadow-[-18px_25px_40px_rgba(109,40,217,0.22)] drop-shadow-[0_12px_24px_rgba(0,0,0,0.15)]">
                <Image
                  src="/landing/phone_mockup_v3.png"
                  alt="Màn hình ứng dụng DealGo trên điện thoại"
                  fill
                  sizes="(max-width: 768px) 325px, 340px"
                  className="object-contain pointer-events-none select-none"
                  priority
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Integrated 4 Features Bar at the Bottom of Hero - Fits cleanly in viewport without overflow */}
      <div className="relative z-20 max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12 w-full pt-1">
        <div className="bg-white/95 backdrop-blur-md rounded-[24px] sm:rounded-[28px] p-3 sm:p-4 shadow-[0_12px_32px_-4px_rgba(0,0,0,0.06)] border border-purple-100/60">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4 lg:divide-x lg:divide-gray-100">
            {features.map((feature, idx) => (
              <div
                key={idx}
                className={`flex items-center gap-3 transition-all duration-200 group ${idx > 0 ? "lg:pl-4" : ""
                  }`}
              >
                {/* Square Icon with rounded-2xl (16px) */}
                <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-[#EDE9FE] flex items-center justify-center flex-shrink-0 group-hover:scale-105 transition-transform shadow-xs">
                  {feature.icon}
                </div>
                <div className="min-w-0">
                  <div className="text-[12px] sm:text-[13px] font-bold text-[#0F172A] leading-tight group-hover:text-[#6D28D9] transition-colors">
                    {feature.title}
                  </div>
                  <div className="text-[10px] sm:text-[11px] text-gray-500 leading-normal mt-0.5">
                    {feature.desc}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
