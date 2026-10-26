export default function TrustSection() {
  const trustFeatures = [
    {
      title: "Xác minh danh tính",
      desc: "Tài xế và đối tác đều được xác minh thông tin.",
      icon: (
        <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" />
        </svg>
      ),
    },
    {
      title: "Theo dõi hành trình/đơn hàng",
      desc: "Minh bạch, rõ ràng theo thời gian thực.",
      icon: (
        <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" />
        </svg>
      ),
    },
    {
      title: "Đánh giá hai chiều",
      desc: "Xây dựng cộng đồng văn minh, chất lượng.",
      icon: (
        <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
        </svg>
      ),
    },
    {
      title: "Hỗ trợ khi có sự cố",
      desc: "Đội ngũ hỗ trợ sẵn sàng xử lý nhanh chóng.",
      icon: (
        <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
          <path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-3 12H7v-2h10v2zm0-3H7V9h10v2zm0-3H7V6h10v2z" />
        </svg>
      ),
    },
  ];

  return (
    <section id="an-toan" className="pt-4 sm:pt-6 pb-3 sm:pb-4 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-3.5 sm:mb-4">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            An toàn và minh bạch —{" "}
            <span className="text-[#6D28D9]">Luôn là ưu tiên hàng đầu</span>
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 mt-1 font-normal">
            DealGo cam kết xây dựng một môi trường an toàn, minh bạch và đáng tin cậy cho tất cả người dùng.
          </p>
        </div>

        {/* 4 Feature Cards Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          {trustFeatures.map((item, i) => (
            <div
              key={i}
              className="bg-[#FAF9FF] rounded-[18px] p-3.5 sm:p-4 border border-purple-100/60 shadow-[0_2px_12px_-4px_rgba(109,40,217,0.03)] flex items-center gap-3.5 hover:border-purple-200 transition-all group"
            >
              {/* Purple Icon Box */}
              <div className="w-10 h-10 rounded-xl bg-[#EDE9FE] flex items-center justify-center flex-shrink-0 shadow-xs group-hover:scale-105 transition-transform">
                {item.icon}
              </div>

              {/* Text Info */}
              <div className="min-w-0">
                <h3 className="font-bold text-xs sm:text-[13px] text-[#0F172A] leading-snug group-hover:text-[#6D28D9] transition-colors">
                  {item.title}
                </h3>
                <p className="text-[11px] text-gray-500 leading-normal mt-0.5 font-normal">
                  {item.desc}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
