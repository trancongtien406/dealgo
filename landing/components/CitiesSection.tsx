import Image from "next/image";

export default function CitiesSection() {
  return (
    <section id="khu-vuc" className="pt-2.5 sm:pt-3 pb-2.5 sm:pb-3 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-2.5 sm:mb-3">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Phục vụ tại Đà Nẵng và mở rộng trong tương lai
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 mt-1 font-normal">
            Hiện tại, DealGo đang phục vụ người dùng tại Đà Nẵng và sẽ sớm có mặt tại nhiều thành phố khác.
          </p>
        </div>

        {/* Cities & Notification Bar */}
        <div className="bg-[#FAF9FF] rounded-[22px] p-3 sm:p-4 border border-purple-100/60 shadow-[0_4px_20px_-4px_rgba(109,40,217,0.03)] flex flex-col xl:flex-row items-center justify-between gap-4">
          {/* Left: 5 Cities in Horizontal Row */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-2.5 sm:gap-3 w-full xl:w-auto xl:flex-1">
            {/* 1. Đà Nẵng (Active) */}
            <div className="bg-white rounded-xl p-2 sm:px-3 flex items-center gap-2.5 shadow-xs border border-purple-100">
              <div className="w-12 h-9 rounded-lg overflow-hidden relative flex-shrink-0">
                <Image
                  src="/images/danang_bridge.jpg"
                  alt="Đà Nẵng Dragon Bridge"
                  fill
                  className="object-cover"
                />
              </div>
              <div className="min-w-0">
                <div className="text-xs font-bold text-[#0F172A] leading-tight">Đà Nẵng</div>
                <span className="inline-block mt-0.5 text-[9px] font-semibold text-[#00D06C] bg-[#DCFCE7] px-1.5 py-0.5 rounded-full leading-none">
                  Đang hoạt động
                </span>
              </div>
            </div>

            {/* 2. Hà Nội (Coming Soon) */}
            <div className="bg-white/80 rounded-xl p-2 sm:px-3 flex items-center gap-2.5 border border-gray-100 opacity-80 hover:opacity-100 transition-opacity">
              <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center flex-shrink-0 text-gray-400">
                <svg className="w-5 h-5 text-gray-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2L2 9h3v12h14V9h3L12 2zm0 4.5l6 4.2V19h-3v-6H9v6H6v-8.3l6-4.2z" />
                </svg>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-semibold text-gray-700 leading-tight">Hà Nội</div>
                <span className="text-[10px] text-gray-400 leading-none">Sắp ra mắt</span>
              </div>
            </div>

            {/* 3. TP. Hồ Chí Minh (Coming Soon) */}
            <div className="bg-white/80 rounded-xl p-2 sm:px-3 flex items-center gap-2.5 border border-gray-100 opacity-80 hover:opacity-100 transition-opacity">
              <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center flex-shrink-0 text-gray-400">
                <svg className="w-5 h-5 text-gray-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M15 11V5l-3-3-3 3v2H3v14h18V11h-6zm-8 8H5v-2h2v2zm0-4H5v-2h2v2zm0-4H5V9h2v2zm6 8h-2v-2h2v2zm0-4h-2v-2h2v2zm0-4h-2V9h2v2zm0-4h-2V5h2v2zm6 12h-2v-2h2v2zm0-4h-2v-2h2v2zm0-4h-2V9h2v2z" />
                </svg>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-semibold text-gray-700 leading-tight">TP. Hồ Chí Minh</div>
                <span className="text-[10px] text-gray-400 leading-none">Sắp ra mắt</span>
              </div>
            </div>

            {/* 4. Nha Trang (Coming Soon) */}
            <div className="bg-white/80 rounded-xl p-2 sm:px-3 flex items-center gap-2.5 border border-gray-100 opacity-80 hover:opacity-100 transition-opacity">
              <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center flex-shrink-0 text-gray-400">
                <svg className="w-5 h-5 text-gray-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M21 16.5c-1.5 0-2.8-.7-3.7-1.8-.9 1.1-2.2 1.8-3.7 1.8s-2.8-.7-3.7-1.8c-.9 1.1-2.2 1.8-3.7 1.8-1.5 0-2.8-.7-3.7-1.8L1 18c1.3 1.3 3.1 2 5 2 1.9 0 3.7-.7 5-2 1.3 1.3 3.1 2 5 2 1.9 0 3.7-.7 5-2l-1.5-1.5h1.5zm0-4c-1.5 0-2.8-.7-3.7-1.8-.9 1.1-2.2 1.8-3.7 1.8s-2.8-.7-3.7-1.8c-.9 1.1-2.2 1.8-3.7 1.8-1.5 0-2.8-.7-3.7-1.8L1 14c1.3 1.3 3.1 2 5 2 1.9 0 3.7-.7 5-2 1.3 1.3 3.1 2 5 2 1.9 0 3.7-.7 5-2l-1.5-1.5h1.5z" />
                </svg>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-semibold text-gray-700 leading-tight">Nha Trang</div>
                <span className="text-[10px] text-gray-400 leading-none">Sắp ra mắt</span>
              </div>
            </div>

            {/* 5. Cần Thơ (Coming Soon) */}
            <div className="bg-white/80 rounded-xl p-2 sm:px-3 flex items-center gap-2.5 border border-gray-100 opacity-80 hover:opacity-100 transition-opacity">
              <div className="w-9 h-9 rounded-lg bg-gray-50 flex items-center justify-center flex-shrink-0 text-gray-400">
                <svg className="w-5 h-5 text-gray-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 12h-2V7.5L12 3 7 7.5V12H5c-1.1 0-2 .9-2 2v6h18v-6c0-1.1-.9-2-2-2zm-8-5.7l3 2.7V12h-6V9l3-2.7zM19 18H5v-2h14v2z" />
                </svg>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-semibold text-gray-700 leading-tight">Cần Thơ</div>
                <span className="text-[10px] text-gray-400 leading-none">Sắp ra mắt</span>
              </div>
            </div>
          </div>

          {/* Right: Expand Notification Callout */}
          <div className="w-full xl:w-auto flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 bg-white/70 xl:bg-transparent rounded-xl p-2.5 xl:p-0 border border-purple-50 xl:border-none pl-2 xl:pl-4">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-full bg-[#EDE9FE] text-[#6D28D9] flex items-center justify-center flex-shrink-0 shadow-xs">
                <svg className="w-4 h-4 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" />
                </svg>
              </div>
              <div>
                <div className="text-xs font-bold text-[#0F172A] leading-tight">
                  Bạn muốn DealGo có mặt tại thành phố của bạn?
                </div>
                <div className="text-[11px] text-gray-500 leading-normal">
                  Hãy để lại thông tin, chúng tôi sẽ thông báo ngay khi sẵn sàng.
                </div>
              </div>
            </div>

            <a
              href="#dang-ky-thong-bao"
              className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full border border-[#6D28D9]/40 text-[#6D28D9] bg-white text-[11px] font-semibold shadow-xs hover:bg-[#6D28D9] hover:text-white transition-all whitespace-nowrap cursor-pointer self-end sm:self-auto"
            >
              <span>Đăng ký nhận thông báo</span>
              <span>→</span>
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
