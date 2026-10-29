import Image from "next/image";

export default function AppExperienceSection() {
  return (
    <section id="trai-nghiem" className="pt-6 sm:pt-8 pb-4 sm:pb-5 bg-[#FBFBFE] scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-4 sm:mb-5">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Trải nghiệm đầy đủ trên một ứng dụng
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 mt-1.5 font-normal">
            Nhiều tính năng hữu ích giúp hành trình và bữa ăn của bạn dễ dàng hơn mỗi ngày.
          </p>
        </div>

        {/* 5 Feature Cards Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 sm:gap-5">
          {/* ============================================================== */}
          {/* Card 1: Theo dõi trực tiếp */}
          {/* ============================================================== */}
          <div className="bg-white rounded-[22px] p-4 sm:p-5 border border-gray-100/90 shadow-[0_4px_20px_-4px_rgba(0,0,0,0.03)] hover:shadow-md hover:border-purple-200 transition-all duration-200 flex flex-col justify-between group">
            {/* Top Visual: Interactive Mini Map */}
            <div className="h-[148px] bg-[#F4F6FA] rounded-[16px] relative overflow-hidden flex items-center justify-center mb-4 border border-gray-100/60">
              {/* Map SVG with roads, green park blocks, and winding route */}
              <svg className="w-full h-full absolute inset-0" viewBox="0 0 200 150" fill="none">
                {/* City Blocks Background */}
                <rect width="200" height="150" fill="#F8FAFC" />

                {/* Soft Green Parks */}
                <rect x="15" y="10" width="45" height="30" rx="6" fill="#DCFCE7" opacity="0.8" />
                <rect x="135" y="80" width="55" height="55" rx="8" fill="#DCFCE7" opacity="0.8" />
                <rect x="85" y="10" width="50" height="25" rx="6" fill="#E2E8F0" opacity="0.4" />

                {/* Road Network (White clean road ribbons) */}
                {/* Horizontal main streets */}
                <path d="M0 45 H200" stroke="#FFFFFF" strokeWidth="16" />
                <path d="M0 100 H200" stroke="#FFFFFF" strokeWidth="14" />
                {/* Vertical streets */}
                <path d="M68 0 V150" stroke="#FFFFFF" strokeWidth="15" />
                <path d="M130 0 V150" stroke="#FFFFFF" strokeWidth="14" />
                <path d="M15 0 V150" stroke="#FFFFFF" strokeWidth="10" />

                {/* Subtle road centerlines */}
                <path d="M0 45 H200" stroke="#E2E8F0" strokeWidth="1" strokeDasharray="4 4" />
                <path d="M68 0 V150" stroke="#E2E8F0" strokeWidth="1" strokeDasharray="4 4" />

                {/* Blue GPS Route */}
                <path
                  d="M25 125 L25 100 Q25 90 35 90 L68 90 Q78 90 78 78 L78 50 Q78 40 90 40 L130 40 Q140 40 140 50 L140 75 Q140 85 152 85 L180 85"
                  fill="none"
                  stroke="#2563EB"
                  strokeWidth="3.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />

                {/* Waypoint dots */}
                <circle cx="25" cy="125" r="3.5" fill="#2563EB" />
                <circle cx="25" cy="125" r="1.5" fill="#FFFFFF" />
                <circle cx="95" cy="40" r="2.5" fill="#60A5FA" />
                <circle cx="180" cy="85" r="3.5" fill="#2563EB" />

                {/* Car 1 (Start near bottom-left) */}
                <g transform="translate(13, 108) scale(0.7)">
                  {/* Shadow */}
                  <rect x="2" y="4" width="24" height="34" rx="7" fill="#0F172A" opacity="0.15" />
                  {/* Tires */}
                  <rect x="0" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="0" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  {/* Body */}
                  <rect x="3" y="3" width="22" height="32" rx="6" fill="#FFFFFF" stroke="#CBD5E1" strokeWidth="1" />
                  {/* Windshields & Roof */}
                  <path d="M6 11 Q14 9 22 11 L20 16 Q14 15 8 16 Z" fill="#334155" />
                  <rect x="7" y="16" width="14" height="9" rx="2" fill="#F1F5F9" />
                  <path d="M8 26 Q14 25 20 26 L21 29 Q14 28 7 29 Z" fill="#334155" />
                  {/* Headlights */}
                  <rect x="5" y="3.5" width="3" height="1.5" rx="0.5" fill="#FEF08A" />
                  <rect x="20" y="3.5" width="3" height="1.5" rx="0.5" fill="#FEF08A" />
                </g>

                {/* Car 2 (Mid-turn at top street) */}
                <g transform="translate(110, 24) rotate(90 14 19) scale(0.7)">
                  {/* Shadow */}
                  <rect x="2" y="4" width="24" height="34" rx="7" fill="#0F172A" opacity="0.15" />
                  {/* Tires */}
                  <rect x="0" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="0" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  {/* Body */}
                  <rect x="3" y="3" width="22" height="32" rx="6" fill="#FFFFFF" stroke="#CBD5E1" strokeWidth="1" />
                  {/* Windshields */}
                  <path d="M6 11 Q14 9 22 11 L20 16 Q14 15 8 16 Z" fill="#334155" />
                  <rect x="7" y="16" width="14" height="9" rx="2" fill="#F1F5F9" />
                  <path d="M8 26 Q14 25 20 26 L21 29 Q14 28 7 29 Z" fill="#334155" />
                </g>

                {/* Car 3 (Destination near right) */}
                <g transform="translate(156, 68) rotate(90 14 19) scale(0.7)">
                  {/* Shadow */}
                  <rect x="2" y="4" width="24" height="34" rx="7" fill="#0F172A" opacity="0.15" />
                  {/* Tires */}
                  <rect x="0" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="7" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="0" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  <rect x="25" y="24" width="3" height="7" rx="1" fill="#1E293B" />
                  {/* Body */}
                  <rect x="3" y="3" width="22" height="32" rx="6" fill="#FFFFFF" stroke="#CBD5E1" strokeWidth="1" />
                  {/* Windshields */}
                  <path d="M6 11 Q14 9 22 11 L20 16 Q14 15 8 16 Z" fill="#334155" />
                  <rect x="7" y="16" width="14" height="9" rx="2" fill="#F1F5F9" />
                  <path d="M8 26 Q14 25 20 26 L21 29 Q14 28 7 29 Z" fill="#334155" />
                </g>
              </svg>
            </div>

            <div>
              <h3 className="font-bold text-[#0F172A] text-sm sm:text-[15px] leading-tight group-hover:text-[#6D28D9] transition-colors">
                Theo dõi trực tiếp
              </h3>
              <p className="text-[11px] sm:text-xs text-gray-500 leading-normal mt-1.5">
                Xem vị trí tài xế, lộ trình di chuyển hoặc trạng thái đơn hàng theo thời gian thực.
              </p>
            </div>
          </div>

          {/* ============================================================== */}
          {/* Card 2: Thương lượng giá linh hoạt */}
          {/* ============================================================== */}
          <div className="bg-white rounded-[22px] p-4 sm:p-5 border border-gray-100/90 shadow-[0_4px_20px_-4px_rgba(0,0,0,0.03)] hover:shadow-md hover:border-purple-200 transition-all duration-200 flex flex-col justify-between group">
            {/* Top Visual: Price Negotiation Cards */}
            <div className="h-[148px] bg-[#F4F6FA] rounded-[16px] p-2.5 relative flex flex-col justify-between mb-4 border border-gray-100/60">
              {/* User Proposal Pill */}
              <div className="bg-white rounded-xl p-1.5 px-2.5 flex items-center gap-2 shadow-[0_2px_8px_rgba(0,0,0,0.04)] border border-gray-50">
                <div className="w-6 h-6 rounded-full bg-[#3B82F6] flex items-center justify-center flex-shrink-0 text-white shadow-xs">
                  <svg className="w-3.5 h-3.5 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                  </svg>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-[10px] text-gray-500 font-normal leading-tight">Đề xuất giá của bạn</div>
                  <div className="flex items-center gap-1 mt-0.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#3B82F6]" />
                    <span className="text-[12px] font-bold text-[#2563EB] leading-none">42.000đ</span>
                  </div>
                </div>
              </div>

              {/* Driver Proposal Pill */}
              <div className="bg-white rounded-xl p-1.5 px-2.5 flex items-center gap-2 shadow-[0_2px_8px_rgba(0,0,0,0.04)] border border-gray-50">
                <div className="w-6 h-6 rounded-full overflow-hidden flex-shrink-0 border border-gray-100 shadow-xs relative">
                  <Image
                    src="/landing/avatar_driver.jpg"
                    alt=""
                    fill
                    sizes="40px"
                    className="object-cover"
                  />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-[10px] text-gray-500 font-normal leading-tight">Tài xế đề xuất</div>
                  <div className="flex items-center gap-1 mt-0.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#3B82F6]" />
                    <span className="text-[12px] font-bold text-[#2563EB] leading-none">45.000đ</span>
                  </div>
                </div>
              </div>

              {/* Accept Button */}
              <button
                type="button"
                className="w-full bg-[#6D28D9] hover:bg-[#5B21B6] text-white text-[11px] font-semibold py-1.5 rounded-xl text-center shadow-xs transition-colors cursor-pointer"
              >
                Chấp nhận mức giá
              </button>
            </div>

            <div>
              <h3 className="font-bold text-[#0F172A] text-sm sm:text-[15px] leading-tight group-hover:text-[#6D28D9] transition-colors">
                Thương lượng giá linh hoạt
              </h3>
              <p className="text-[11px] sm:text-xs text-gray-500 leading-normal mt-1.5">
                Chủ động đề xuất mức giá và chọn tài xế phù hợp.
              </p>
            </div>
          </div>

          {/* ============================================================== */}
          {/* Card 3: Thanh toán an toàn */}
          {/* ============================================================== */}
          <div className="bg-white rounded-[22px] p-4 sm:p-5 border border-gray-100/90 shadow-[0_4px_20px_-4px_rgba(0,0,0,0.03)] hover:shadow-md hover:border-purple-200 transition-all duration-200 flex flex-col justify-between group">
            {/* Top Visual: 3 Payment Methods (Vector graphics) */}
            <div className="h-[148px] bg-[#F4F6FA] rounded-[16px] p-2.5 relative flex items-center justify-center gap-2 mb-4 border border-gray-100/60">
              {/* Method 1: Ví điện tử */}
              <div className="flex-1 h-[106px] bg-white rounded-xl p-2 flex flex-col items-center justify-center text-center shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-gray-100/70">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#EDE9FE] to-[#DDD6FE] flex items-center justify-center mb-1.5 shadow-xs">
                  {/* Purple Wallet Vector SVG */}
                  <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />
                  </svg>
                </div>
                <span className="text-[10px] font-semibold text-gray-700 leading-tight">Ví điện tử</span>
              </div>

              {/* Method 2: Thẻ ngân hàng */}
              <div className="flex-1 h-[106px] bg-white rounded-xl p-2 flex flex-col items-center justify-center text-center shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-gray-100/70">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#DBEAFE] to-[#BFDBFE] flex items-center justify-center mb-1.5 shadow-xs">
                  {/* Blue Bank Card Vector SVG */}
                  <svg className="w-5 h-5 text-[#2563EB]" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z" />
                  </svg>
                </div>
                <span className="text-[10px] font-semibold text-gray-700 leading-tight">Thẻ ngân hàng</span>
              </div>

              {/* Method 3: Tiền mặt */}
              <div className="flex-1 h-[106px] bg-white rounded-xl p-2 flex flex-col items-center justify-center text-center shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-gray-100/70">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#DCFCE7] to-[#BBF7D0] flex items-center justify-center mb-1.5 shadow-xs">
                  {/* Green Cash Vector SVG */}
                  <svg className="w-5 h-5 text-[#00D06C]" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm8 3H5V8h14v8z" />
                  </svg>
                </div>
                <span className="text-[10px] font-semibold text-gray-700 leading-tight">Tiền mặt</span>
              </div>
            </div>

            <div>
              <h3 className="font-bold text-[#0F172A] text-sm sm:text-[15px] leading-tight group-hover:text-[#6D28D9] transition-colors">
                Thanh toán an toàn
              </h3>
              <p className="text-[11px] sm:text-xs text-gray-500 leading-normal mt-1.5">
                Tiền mặt hoặc thanh toán trực tuyến (ví điện tử, thẻ) khi được hỗ trợ.
              </p>
            </div>
          </div>

          {/* ============================================================== */}
          {/* Card 4: Đánh giá hai chiều */}
          {/* ============================================================== */}
          <div className="bg-white rounded-[22px] p-4 sm:p-5 border border-gray-100/90 shadow-[0_4px_20px_-4px_rgba(0,0,0,0.03)] hover:shadow-md hover:border-purple-200 transition-all duration-200 flex flex-col justify-between group">
            {/* Top Visual: Driver Rating Card */}
            <div className="h-[148px] bg-[#F4F6FA] rounded-[16px] p-3 relative flex flex-col justify-center gap-2.5 mb-4 border border-gray-100/60">
              {/* Rating header with avatar, score & stars */}
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-full overflow-hidden border border-gray-100 shadow-xs relative flex-shrink-0">
                  <Image
                    src="/landing/avatar_customer.jpg"
                    alt=""
                    fill
                    sizes="40px"
                    className="object-cover"
                  />
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="flex items-center text-[#F59E0B] text-xs gap-0.5">
                    <span>★</span>
                    <span>★</span>
                    <span>★</span>
                    <span>★</span>
                    <span>★</span>
                  </div>
                </div>
              </div>

              {/* Review Quote Bubble */}
              <div className="bg-white rounded-xl p-2 px-2.5 shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-gray-100/70 flex items-start gap-1.5">
                <span className="text-[#F59E0B] text-xs leading-none mt-0.5">★</span>
                <p className="text-[10px] text-gray-600 leading-snug">
                  Chấm sao và nhận xét sau mỗi chuyến đi, đơn hàng.
                </p>
              </div>
            </div>

            <div>
              <h3 className="font-bold text-[#0F172A] text-sm sm:text-[15px] leading-tight group-hover:text-[#6D28D9] transition-colors">
                Đánh giá hai chiều
              </h3>
              <p className="text-[11px] sm:text-xs text-gray-500 leading-normal mt-1.5">
                Khách hàng và tài xế đánh giá lẫn nhau sau mỗi giao dịch.
              </p>
            </div>
          </div>

          {/* ============================================================== */}
          {/* Card 5: Liên lạc dễ dàng */}
          {/* ============================================================== */}
          <div className="bg-white rounded-[22px] p-4 sm:p-5 border border-gray-100/90 shadow-[0_4px_20px_-4px_rgba(0,0,0,0.03)] hover:shadow-md hover:border-purple-200 transition-all duration-200 flex flex-col justify-between group">
            {/* Top Visual: Chat & Call Buttons */}
            <div className="h-[148px] bg-[#F4F6FA] rounded-[16px] p-2.5 relative flex flex-col justify-between mb-4 border border-gray-100/60">
              {/* Top row: Chat bubble + User avatar */}
              <div className="flex items-center justify-between gap-2">
                <div className="bg-white rounded-xl px-2.5 py-1.5 shadow-[0_2px_6px_rgba(0,0,0,0.03)] border border-gray-100/70 flex flex-col gap-1 w-[100px]">
                  <div className="h-1.5 w-14 bg-gray-200 rounded-full" />
                  <div className="h-1.5 w-8 bg-gray-150 rounded-full" />
                </div>
                <div className="w-8 h-8 rounded-full overflow-hidden border border-gray-100 shadow-xs relative flex-shrink-0">
                  <Image
                    src="/landing/avatar_customer.jpg"
                    alt=""
                    fill
                    sizes="40px"
                    className="object-cover"
                  />
                </div>
              </div>

              {/* Middle row: Two action call buttons */}
              <div className="flex items-center gap-2 pl-1">
                {/* Purple phone button */}
                <button
                  type="button"
                  aria-label="Call voice"
                  className="w-7 h-7 rounded-full bg-[#6D28D9] flex items-center justify-center text-white shadow-xs hover:scale-105 transition-transform"
                >
                  <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 00-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z" />
                  </svg>
                </button>

                {/* Green call button */}
                <button
                  type="button"
                  aria-label="Call chat"
                  className="w-7 h-7 rounded-full bg-[#00D06C] flex items-center justify-center text-white shadow-xs hover:scale-105 transition-transform"
                >
                  <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 00-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z" />
                  </svg>
                </button>
              </div>

              {/* Bottom row: Reply chat bubble */}
              <div className="self-end bg-white rounded-xl px-2.5 py-1.5 shadow-[0_2px_6px_rgba(0,0,0,0.03)] border border-gray-100/70 flex flex-col gap-1 w-[110px]">
                <div className="h-1.5 w-16 bg-gray-200 rounded-full" />
                <div className="h-1.5 w-10 bg-gray-150 rounded-full" />
              </div>
            </div>

            <div>
              <h3 className="font-bold text-[#0F172A] text-sm sm:text-[15px] leading-tight group-hover:text-[#6D28D9] transition-colors">
                Liên lạc dễ dàng
              </h3>
              <p className="text-[11px] sm:text-xs text-gray-500 leading-normal mt-1.5">
                Nhắn tin hoặc gọi thoại trong ứng dụng theo từng chuyến, đơn hàng.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
