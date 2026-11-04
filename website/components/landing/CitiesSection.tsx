export default function CitiesSection({ comingSoon = [] }: { comingSoon?: string[] }) {
  return (
    <section id="khu-vuc" className="pt-2.5 sm:pt-3 pb-2.5 sm:pb-3 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-2.5 sm:mb-3">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Phủ sóng toàn quốc
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 mt-1 font-normal">
            DealGo phục vụ khách hàng, quán ăn và tài xế trên cả nước. Khu vực mới mở sẽ được cập nhật trong ứng dụng.
          </p>
        </div>

        {/* Coverage & Notification Bar */}
        <div className="bg-[#FAF9FF] rounded-[22px] p-3 sm:p-4 border border-purple-100/60 shadow-[0_4px_20px_-4px_rgba(109,40,217,0.03)] flex flex-col xl:flex-row items-center justify-between gap-4">
          {/* Left: coverage card + admin-managed upcoming cities */}
          <div className="flex flex-wrap gap-2.5 sm:gap-3 w-full xl:w-auto xl:flex-1">
            {/* Nationwide coverage */}
            <div className="bg-white rounded-xl p-2 sm:px-3 flex items-center gap-2.5 shadow-xs border border-purple-100">
              <div className="w-12 h-9 rounded-lg overflow-hidden relative flex-shrink-0 bg-gradient-to-br from-[#6D28D9] to-[#00D06C] flex items-center justify-center">
                <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 110-5 2.5 2.5 0 010 5z" />
                </svg>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-bold text-[#0F172A] leading-tight">Toàn quốc</div>
                <span className="inline-block mt-0.5 text-[9px] font-semibold text-[#00D06C] bg-[#DCFCE7] px-1.5 py-0.5 rounded-full leading-none">
                  Đang hoạt động
                </span>
              </div>
            </div>

            {comingSoon.map((city) => (
              <div key={city} className="bg-white rounded-xl p-2 sm:px-3 flex items-center gap-2.5 shadow-xs border border-gray-100">
                <div className="min-w-0">
                  <div className="text-xs font-bold text-[#0F172A] leading-tight">{city}</div>
                  <span className="inline-block mt-0.5 text-[9px] font-semibold text-[#6D28D9] bg-[#EDE9FE] px-1.5 py-0.5 rounded-full leading-none">
                    Sắp có
                  </span>
                </div>
              </div>
            ))}
          </div>

          {/* Right: Expand Notification Callout */}
          <div className="w-full xl:w-auto flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 bg-white/70 xl:bg-transparent rounded-xl p-2.5 xl:p-0 border border-purple-50 xl:border-none pl-2 xl:pl-4">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-full bg-[#EDE9FE] text-[#6D28D9] flex items-center justify-center flex-shrink-0 shadow-xs">
                <svg className="w-4 h-4 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" />
                </svg>
              </div>
              <div>
                <div className="text-xs font-bold text-[#0F172A] leading-tight">
                  Bạn muốn DealGo có mặt tại thành phố của bạn?
                </div>
                <div className="text-[11px] text-gray-500 leading-normal">
                  Liên hệ DealGo qua trang Hỗ trợ để góp ý khu vực mới.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
