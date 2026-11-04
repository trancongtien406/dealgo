import type { PublicSiteConfig } from "@/features/site-config/types";

export default function Footer({ siteConfig = {} }: { siteConfig?: PublicSiteConfig }) {
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
              Giá do bạn chọn · Trọn gói hành trình
            </div>

            {/* Description */}
            <p className="text-[11px] sm:text-xs text-gray-500 leading-relaxed font-normal">
              Nền tảng đặt xe (Bike, Car) và đặt đồ ăn trên toàn quốc, kết nối khách hàng, quán ăn/cửa hàng và tài xế; khách chủ động đề xuất và thương lượng giá chuyến xe.
            </p>

            {siteConfig.contactEmail || siteConfig.hotline ? (
              <ul className="space-y-1 text-[11px] sm:text-xs text-gray-500">
                {siteConfig.hotline ? (
                  <li>
                    Hotline:{" "}
                    <a href={`tel:${siteConfig.hotline.replace(/[^0-9+]/g, "")}`} className="font-semibold text-[#0F172A] hover:text-[#6D28D9]">
                      {siteConfig.hotline}
                    </a>
                  </li>
                ) : null}
                {siteConfig.contactEmail ? (
                  <li>
                    Email:{" "}
                    <a href={`mailto:${siteConfig.contactEmail}`} className="font-semibold text-[#0F172A] hover:text-[#6D28D9]">
                      {siteConfig.contactEmail}
                    </a>
                  </li>
                ) : null}
              </ul>
            ) : null}
          </div>

          {/* ============================================================== */}
          {/* 2. Center: 4 Navigation Columns (Spread evenly) */}
          {/* ============================================================== */}
          <div className="flex-1 w-full flex flex-wrap justify-between gap-6 sm:gap-8 max-w-[660px]">
            {/* Dịch vụ */}
            <div className="min-w-[85px] space-y-2">
              <h2 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Dịch vụ
              </h2>
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
              </ul>
            </div>

            {/* Về DealGo */}
            <div className="min-w-[105px] space-y-2">
              <h2 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Về DealGo
              </h2>
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
                  <a href="#faq" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Hỗ trợ
                  </a>
                </li>
              </ul>
            </div>

            {/* Hỗ trợ */}
            <div className="min-w-[110px] space-y-2">
              <h2 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Hỗ trợ
              </h2>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="#faq" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Trung tâm trợ giúp
                  </a>
                </li>
                <li>
                  <a href="/support" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Liên hệ
                  </a>
                </li>
                <li>
                  <a href="/support" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Góp ý
                  </a>
                </li>
              </ul>
            </div>

            {/* Điều khoản */}
            <div className="min-w-[115px] space-y-2">
              <h2 className="font-bold text-xs sm:text-[13px] text-[#0F172A] whitespace-nowrap">
                Điều khoản
              </h2>
              <ul className="space-y-1.5 text-xs text-gray-500 font-normal">
                <li>
                  <a href="/terms" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Điều khoản sử dụng
                  </a>
                </li>
                <li>
                  <a href="/privacy" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Chính sách bảo mật
                  </a>
                </li>
                <li>
                  <a href="/regulations" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Quy chế sử dụng
                  </a>
                </li>
                <li>
                  <a href="/account-deletion" className="hover:text-[#6D28D9] transition-colors whitespace-nowrap">
                    Xoá tài khoản
                  </a>
                </li>
              </ul>
            </div>
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
