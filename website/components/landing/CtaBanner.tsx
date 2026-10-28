import Image from "next/image";

export default function CtaBanner() {
  return (
    <div className="relative bg-gradient-to-br from-[#6D28D9] via-[#7C3AED] to-[#4F46E5] rounded-[24px] p-6 sm:p-7 text-white overflow-hidden shadow-[0_8px_30px_rgba(109,40,217,0.18)] flex flex-col md:flex-row items-center justify-between gap-6 min-h-[300px]">
      {/* Background Subtle Gradient Blobs & Da Nang Coast Artwork */}
      <div className="absolute top-0 right-0 w-72 h-72 bg-white/10 rounded-full blur-2xl -translate-y-20 translate-x-20 pointer-events-none" />
      <div className="absolute bottom-0 left-0 w-64 h-64 bg-indigo-900/30 rounded-full blur-xl translate-y-20 -translate-x-20 pointer-events-none" />

      {/* Coast / Mountain Landscape Silhouette in bottom right */}
      <svg
        className="absolute bottom-0 right-0 w-72 h-36 opacity-15 pointer-events-none"
        viewBox="0 0 300 150"
        fill="currentColor"
      >
        <path d="M0,150 L60,110 Q90,90 120,115 T180,95 Q220,70 260,120 L300,150 Z" />
      </svg>

      {/* Left Content */}
      <div className="relative z-10 flex-1 space-y-3.5 max-w-[340px]">
        {/* Pill Tag */}
        <div className="inline-block bg-white/20 backdrop-blur-md text-white/95 text-[11px] font-semibold px-3 py-1 rounded-full border border-white/20 shadow-xs">
          Tải ứng dụng DealGo
        </div>

        {/* Headline */}
        <h3 className="text-xl sm:text-2xl font-extrabold text-white leading-tight">
          Sẵn sàng trải nghiệm những chuyến đi tuyệt vời và món ngon mỗi ngày?
        </h3>

        {/* QR Code & Store Buttons */}
        <div className="pt-2 flex flex-wrap items-center gap-3">
          {/* QR Code Graphic */}
          <div className="w-16 h-16 bg-white p-1 rounded-xl shadow-md flex-shrink-0 flex items-center justify-center">
            <svg viewBox="0 0 45 45" className="w-full h-full text-black">
              {/* Corner 1 */}
              <rect x="3" y="3" width="12" height="12" fill="currentColor" rx="2" />
              <rect x="5" y="5" width="8" height="8" fill="white" rx="1" />
              <rect x="7" y="7" width="4" height="4" fill="currentColor" />
              {/* Corner 2 */}
              <rect x="30" y="3" width="12" height="12" fill="currentColor" rx="2" />
              <rect x="32" y="5" width="8" height="8" fill="white" rx="1" />
              <rect x="34" y="7" width="4" height="4" fill="currentColor" />
              {/* Corner 3 */}
              <rect x="3" y="30" width="12" height="12" fill="currentColor" rx="2" />
              <rect x="5" y="32" width="8" height="8" fill="white" rx="1" />
              <rect x="7" y="34" width="4" height="4" fill="currentColor" />
              {/* Data pattern */}
              <rect x="18" y="4" width="3" height="3" fill="currentColor" />
              <rect x="23" y="7" width="3" height="3" fill="currentColor" />
              <rect x="18" y="12" width="3" height="3" fill="currentColor" />
              <rect x="23" y="14" width="3" height="3" fill="currentColor" />
              <rect x="4" y="18" width="3" height="3" fill="currentColor" />
              <rect x="9" y="22" width="3" height="3" fill="currentColor" />
              <rect x="18" y="18" width="8" height="8" fill="currentColor" rx="1" />
              <rect x="20" y="20" width="4" height="4" fill="white" />
              <rect x="30" y="18" width="3" height="3" fill="currentColor" />
              <rect x="36" y="22" width="3" height="3" fill="currentColor" />
              <rect x="18" y="30" width="3" height="3" fill="currentColor" />
              <rect x="23" y="34" width="3" height="3" fill="currentColor" />
              <rect x="30" y="30" width="3" height="3" fill="currentColor" />
              <rect x="34" y="34" width="3" height="3" fill="currentColor" />
              <rect x="38" y="38" width="3" height="3" fill="currentColor" />
            </svg>
          </div>

          {/* App Store & Google Play */}
          <div className="flex flex-col gap-1.5">
            {/* App Store */}
            <a
              href="#app-store"
              className="flex items-center gap-2 bg-black hover:bg-black/80 text-white rounded-lg px-2.5 py-1.5 border border-white/10 transition-colors shadow-xs"
            >
              <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              <div className="text-left">
                <div className="text-[7px] text-gray-300 leading-none">Tải về trên</div>
                <div className="text-[10px] font-bold leading-tight">App Store</div>
              </div>
            </a>

            {/* Google Play */}
            <a
              href="#google-play"
              className="flex items-center gap-2 bg-black hover:bg-black/80 text-white rounded-lg px-2.5 py-1.5 border border-white/10 transition-colors shadow-xs"
            >
              <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3.18 23.76a2 2 0 001.05-.31L15.31 17 12 13.68zM20.9 10.56L17.95 8.9l-3.33 3.33 3.33 3.34 2.98-1.68a1.93 1.93 0 000-3.33zM2.05.24A2 2 0 001.5 1.74v20.52a2 2 0 00.55 1.5L12 13.68z" />
              </svg>
              <div className="text-left">
                <div className="text-[7px] text-gray-300 leading-none">TẢI VỀ TRÊN</div>
                <div className="text-[10px] font-bold leading-tight">Google Play</div>
              </div>
            </a>
          </div>
        </div>
      </div>

      {/* Right Phone Mockup with Floating Badges */}
      <div className="relative z-10 w-full md:w-[220px] flex items-center justify-center flex-shrink-0 pt-4 md:pt-0">
        {/* Floating Car Badge (Left) */}
        <div className="absolute left-0 sm:-left-3 top-1/4 -translate-y-1/2 w-9 h-9 rounded-full bg-white text-[#6D28D9] flex items-center justify-center shadow-lg z-20">
          <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
          </svg>
        </div>

        {/* Floating Shopping Bag Badge (Right) */}
        <div className="absolute right-0 sm:-right-3 bottom-1/4 translate-y-1/2 w-9 h-9 rounded-full bg-[#00D06C] text-white flex items-center justify-center shadow-lg z-20">
          <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
            <path d="M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm7 17H5V8h14v12z" />
          </svg>
        </div>

        {/* Realistic Phone Shell */}
        <div className="relative w-[150px] sm:w-[165px] h-[270px] sm:h-[300px] drop-shadow-2xl">
          <Image
            src="/landing/phone_mockup_v3.png"
            alt="DealGo mobile app"
            fill
            className="object-contain"
            priority
          />
        </div>
      </div>
    </div>
  );
}
