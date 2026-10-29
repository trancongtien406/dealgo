import Image from "next/image";

export default function CtaBanner() {
  return (
    <div id="tai-ung-dung" className="relative bg-gradient-to-br from-[#6D28D9] via-[#7C3AED] to-[#4F46E5] rounded-[24px] p-6 sm:p-7 text-white overflow-hidden shadow-[0_8px_30px_rgba(109,40,217,0.18)] flex flex-col md:flex-row items-center justify-between gap-6 min-h-[300px]">
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
        <h2 className="text-xl sm:text-2xl font-extrabold text-white leading-tight">
          Đặt xe, thương lượng giá và đặt đồ ăn trong một ứng dụng.
        </h2>

        {/* OPEN DECISION: App Store / Google Play links and a real QR code are not published yet. */}
        <p className="pt-2 text-sm font-semibold text-white/95">
          Ứng dụng sắp có trên App Store và Google Play
        </p>
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
            alt="Ứng dụng DealGo trên điện thoại"
            fill
            sizes="165px"
            className="object-contain"
          />
        </div>
      </div>
    </div>
  );
}
