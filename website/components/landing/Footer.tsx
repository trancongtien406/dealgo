"use client";

export default function Footer() {
  return (
    <footer id="footer" className="bg-white border-t border-gray-100 pt-8 sm:pt-10 pb-6">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Main Footer Row */}
        <div className="flex flex-col lg:flex-row items-start justify-between gap-8 lg:gap-10 pb-8">
          {/* ============================================================== */}
          {/* 1. Left: Brand Info */}
          {/* ============================================================== */}
          <div className="w-full lg:w-[320px] shrink-0 space-y-2.5">
            {/* Logo */}
            <div className="flex items-center gap-1.5">
              <span className="text-[26px] font-black tracking-tight leading-none">
                <span className="text-[#6D28D9]">Deal</span>
                <span className="text-[#00D06C]">Go</span>
              </span>
            </div>

            {/* Slogan */}
            <div className="text-[11px] text-gray-400 font-normal leading-tight">
              Đi muôn nơi · Mua vạn món
            </div>

            {/* Description */}
            <p className="text-[11px] sm:text-xs text-gray-500 leading-relaxed font-normal">
              Nền tảng kết nối khách hàng, quán ăn, cửa hàng và tài xế. Đi muôn nơi. Mua vạn món. Chủ động cùng DealGo.
            </p>

            {/* 4 Social Icons */}
            <div className="flex items-center gap-2 pt-1">
              {/* Facebook */}
              <a
                href="#facebook"
                aria-label="DealGo Facebook"
                className="w-6 h-6 rounded-full bg-[#1877F2] text-white flex items-center justify-center hover:opacity-90 transition-opacity shadow-xs"
              >
                <svg className="w-3 h-3 fill-current" viewBox="0 0 24 24">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </a>

              {/* Instagram */}
              <a
                href="#instagram"
                aria-label="DealGo Instagram"
                className="w-6 h-6 rounded-md bg-gradient-to-tr from-[#F58529] via-[#DD2A7B] to-[#8134AF] text-white flex items-center justify-center hover:opacity-90 transition-opacity shadow-xs"
              >
                <svg className="w-3 h-3 fill-current" viewBox="0 0 24 24">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z" />
                </svg>
              </a>

              {/* TikTok */}
              <a
                href="#tiktok"
                aria-label="DealGo TikTok"
                className="w-6 h-6 rounded-full bg-black text-white flex items-center justify-center hover:opacity-90 transition-opacity shadow-xs"
              >
                <svg className="w-3 h-3 fill-current" viewBox="0 0 24 24">
                  <path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1V9.01a6.33 6.33 0 00-.79-.05 6.34 6.34 0 00-6.34 6.34 6.34 6.34 0 006.34 6.34 6.34 6.34 0 006.33-6.34V8.69a8.17 8.17 0 004.77 1.52V6.75a4.85 4.85 0 01-1-.06z" />
                </svg>
              </a>

              {/* X / Twitter */}
              <a
                href="#x"
                aria-label="DealGo X"
                className="w-6 h-6 rounded-full bg-black text-white flex items-center justify-center hover:opacity-90 transition-opacity shadow-xs"
              >
                <svg className="w-2.5 h-2.5 fill-current" viewBox="0 0 24 24">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
            </div>
          </div>

          {/* ============================================================== */}
          {/* 2. Center: 4 Navigation Columns (Spread evenly) */}
          {/* ============================================================== */}
          <div className="flex-1 w-full flex flex-wrap justify-between gap-6 sm:gap-8 max-w-[660px]">
            {/* Dịch vụ */}
            <div className="min-w-[85px] space-y-2">
              <h4 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Dịch vụ
              </h4>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="#dat-xe" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Đặt xe
                  </a>
                </li>
                <li>
                  <a href="#do-an" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Đồ ăn
                  </a>
                </li>
                <li>
                  <a href="#mua-hang" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Mua hàng
                  </a>
                </li>
              </ul>
            </div>

            {/* Về DealGo */}
            <div className="min-w-[105px] space-y-2">
              <h4 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Về DealGo
              </h4>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="#cach-hoat-dong" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Cách hoạt động
                  </a>
                </li>
                <li>
                  <a href="#doi-tac" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Đối tác
                  </a>
                </li>
                <li>
                  <a href="#an-toan" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    An toàn
                  </a>
                </li>
                <li>
                  <a href="#ho-tro" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Hỗ trợ
                  </a>
                </li>
              </ul>
            </div>

            {/* Hỗ trợ */}
            <div className="min-w-[110px] space-y-2">
              <h4 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Hỗ trợ
              </h4>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="#faq" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Trung tâm trợ giúp
                  </a>
                </li>
                <li>
                  <a href="#lien-he" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Liên hệ
                  </a>
                </li>
                <li>
                  <a href="#gop-y" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Góp ý
                  </a>
                </li>
              </ul>
            </div>

            {/* Điều khoản */}
            <div className="min-w-[115px] space-y-2">
              <h4 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Điều khoản
              </h4>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="#dieu-khoan" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Điều khoản sử dụng
                  </a>
                </li>
                <li>
                  <a href="#chinh-sach" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Chính sách bảo mật
                  </a>
                </li>
                <li>
                  <a href="#quy-dinh" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Quy định đối tác
                  </a>
                </li>
              </ul>
            </div>
          </div>

          {/* ============================================================== */}
          {/* 3. Right: Newsletter Box (Wide & spacious) */}
          {/* ============================================================== */}
          <div className="w-full lg:w-[280px] xl:w-[300px] shrink-0 bg-[#F6F4FE] rounded-[18px] p-4 sm:p-4.5 border border-purple-100/60 shadow-xs space-y-2.5">
            <h4 className="font-bold text-xs sm:text-[13px] text-[#0F172A] tracking-tight whitespace-nowrap">
              Nhận thông tin mới nhất
            </h4>

            {/* Input + Purple Send Button */}
            <form
              onSubmit={(e) => e.preventDefault()}
              className="flex items-center bg-white rounded-xl p-1 pl-3 shadow-xs border border-gray-100 focus-within:border-[#6D28D9] transition-all"
            >
              <input
                type="email"
                placeholder="Nhập email của bạn"
                className="w-full bg-transparent text-xs text-gray-700 placeholder-gray-400 focus:outline-none min-w-0"
              />
              <button
                type="submit"
                aria-label="Gửi email nhận tin"
                className="w-8 h-8 rounded-lg bg-[#6D28D9] hover:bg-[#5B21B6] text-white flex items-center justify-center shrink-0 transition-colors shadow-xs cursor-pointer ml-1"
              >
                <svg
                  className="w-3.5 h-3.5 text-white -rotate-45 -translate-y-0.5 translate-x-0.5"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
                </svg>
              </button>
            </form>
          </div>
        </div>

        {/* Bottom Sub-bar */}
        <div className="pt-2 flex flex-col sm:flex-row items-center justify-between gap-2 text-[11px] text-gray-400 font-normal">
          <div>© 2026 DealGo. Tất cả quyền được bảo lưu.</div>
          <div className="flex items-center gap-1">
            <span>Thiết kế tại Việt Nam</span>
            <span className="text-red-500">❤️</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
