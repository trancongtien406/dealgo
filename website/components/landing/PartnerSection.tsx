import Image from "next/image";

export default function PartnerSection() {
  return (
    <section id="doi-tac" className="pt-5 sm:pt-7 pb-2.5 sm:pb-3 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-3.5 sm:mb-4">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Dành cho đối tác
          </h2>
        </div>

        {/* 2 Partner Cards Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* ============================================================== */}
          {/* Card 1: Dành cho quán ăn, cửa hàng (Merchant) */}
          {/* ============================================================== */}
          <div className="bg-[#FAF9FF] rounded-[24px] p-6 sm:p-7 border border-purple-100/60 shadow-[0_4px_24px_-4px_rgba(109,40,217,0.03)] flex flex-col sm:flex-row items-center justify-between gap-6 group hover:border-purple-200 transition-all duration-200">
            {/* Left Content */}
            <div className="flex-1 space-y-3.5">
              {/* Badge + Subtitle */}
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-[#00D06C] flex items-center justify-center text-white shadow-xs flex-shrink-0">
                  <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm7 17H5V8h14v12z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-bold text-[#00D06C] text-sm sm:text-[15px] leading-tight">
                    Dành cho quán ăn, cửa hàng
                  </h3>
                </div>
              </div>

              {/* Description */}
              <p className="text-xs text-gray-500 leading-relaxed font-normal">
                Tham gia DealGo để tiếp cận thêm nhiều khách hàng và tăng doanh thu dễ dàng.
              </p>

              {/* 4 Checkmark Points */}
              <ul className="space-y-1.5 text-xs text-gray-600">
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Gia nhập nhanh, dễ dàng</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Quản lý đơn hàng thuận tiện</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Tiếp cận khách hàng gần bạn</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Nhiều chương trình ưu đãi hỗ trợ</span>
                </li>
              </ul>

              {/* CTA Button */}
              <div className="pt-2">
                <a
                  href="#dang-ky-quan"
                  className="inline-flex items-center gap-2 px-5 py-2 rounded-full border border-[#6D28D9]/40 text-[#6D28D9] bg-white text-xs font-semibold shadow-xs hover:bg-[#6D28D9] hover:text-white transition-all cursor-pointer"
                >
                  <span>Đăng ký quán ngay</span>
                  <span>→</span>
                </a>
              </div>
            </div>

            {/* Right Photo with Floating Store Badge */}
            <div className="relative w-full sm:w-[210px] lg:w-[220px] h-[190px] sm:h-[210px] flex-shrink-0">
              <div className="w-full h-full rounded-[20px] overflow-hidden shadow-sm relative border border-gray-100">
                <Image
                  src="/landing/partner_merchant.jpg"
                  alt="Đối tác quán ăn DealGo"
                  fill
                  className="object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>

              {/* Floating Green Storefront Badge */}
              <div className="absolute -left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-[#00D06C] text-white flex items-center justify-center shadow-md border-2 border-white">
                <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z" />
                </svg>
              </div>
            </div>
          </div>

          {/* ============================================================== */}
          {/* Card 2: Dành cho tài xế (Driver) */}
          {/* ============================================================== */}
          <div className="bg-[#FAF9FF] rounded-[24px] p-6 sm:p-7 border border-purple-100/60 shadow-[0_4px_24px_-4px_rgba(109,40,217,0.03)] flex flex-col sm:flex-row items-center justify-between gap-6 group hover:border-purple-200 transition-all duration-200">
            {/* Left Content */}
            <div className="flex-1 space-y-3.5">
              {/* Badge + Subtitle */}
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-[#6D28D9] flex items-center justify-center text-white shadow-xs flex-shrink-0">
                  <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-bold text-[#6D28D9] text-sm sm:text-[15px] leading-tight">
                    Dành cho tài xế
                  </h3>
                </div>
              </div>

              {/* Description */}
              <p className="text-xs text-gray-500 leading-relaxed font-normal">
                Trở thành tài xế đối tác của DealGo và chủ động tăng thu nhập theo thời gian linh hoạt.
              </p>

              {/* 4 Checkmark Points */}
              <ul className="space-y-1.5 text-xs text-gray-600">
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Tự do chọn chuyến, thương lượng giá</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Thu nhập minh bạch, thanh toán nhanh</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Hỗ trợ 24/7 trong suốt hành trình</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-[#00D06C] font-bold text-sm">✓</span>
                  <span>Môi trường an toàn, chuyên nghiệp</span>
                </li>
              </ul>

              {/* CTA Button */}
              <div className="pt-2">
                <a
                  href="#tro-thanh-tai-xe"
                  className="inline-flex items-center gap-2 px-5 py-2 rounded-full border border-[#6D28D9]/40 text-[#6D28D9] bg-white text-xs font-semibold shadow-xs hover:bg-[#6D28D9] hover:text-white transition-all cursor-pointer"
                >
                  <span>Trở thành tài xế</span>
                  <span>→</span>
                </a>
              </div>
            </div>

            {/* Right Photo with Floating Purple Car Badge */}
            <div className="relative w-full sm:w-[210px] lg:w-[220px] h-[190px] sm:h-[210px] flex-shrink-0">
              <div className="w-full h-full rounded-[20px] overflow-hidden shadow-sm relative border border-gray-100">
                <Image
                  src="/landing/partner_driver.jpg"
                  alt="Đối tác tài xế DealGo"
                  fill
                  className="object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>

              {/* Floating Purple Car Badge */}
              <div className="absolute -left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-[#6D28D9] text-white flex items-center justify-center shadow-md border-2 border-white">
                <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                </svg>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
