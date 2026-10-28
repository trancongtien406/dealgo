export default function FeaturesStrip() {
  const features = [
    {
      icon: (
        <svg className="w-6 h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
        </svg>
      ),
      title: "Chủ động thương lượng giá",
      desc: "Đặt xe với mức giá phù hợp",
    },
    {
      icon: (
        <svg className="w-6 h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <rect x="5" y="2" width="14" height="20" rx="3" />
          <line x1="12" y1="18" x2="12.01" y2="18" strokeWidth={3} strokeLinecap="round" />
        </svg>
      ),
      title: "Một ứng dụng, nhiều nhu cầu",
      desc: "Đặt xe, đồ ăn, mua sắm...",
    },
    {
      icon: (
        <svg className="w-6 h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <polyline points="12 6 12 12 16 14" />
        </svg>
      ),
      title: "Theo dõi minh bạch",
      desc: "Biết rõ hành trình và trạng thái đơn",
    },
    {
      icon: (
        <svg className="w-6 h-6 text-[#6D28D9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M3 18v-6a9 9 0 0118 0v6" />
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 19a2 2 0 01-2 2h-1a2 2 0 01-2-2v-3a2 2 0 012-2h3zM3 19a2 2 0 002 2h1a2 2 0 002-2v-3a2 2 0 00-2-2H3z" />
        </svg>
      ),
      title: "Hỗ trợ nhanh chóng",
      desc: "Đội ngũ chăm sóc khách hàng luôn sẵn sàng",
    },
  ];

  return (
    <section id="features-strip" className="relative z-20 py-4 pb-12 bg-[#F8F7FF]">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Unified large container with rounded-[28px] matching the reference image */}
        <div className="bg-white/95 backdrop-blur-md rounded-[28px] p-4 sm:p-6 shadow-[0_12px_32px_-4px_rgba(0,0,0,0.06)] border border-purple-100/60">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 lg:divide-x lg:divide-gray-100">
            {features.map((feature, idx) => (
              <div
                key={idx}
                className={`flex items-center gap-4 transition-all duration-200 group ${
                  idx > 0 ? "lg:pl-6" : ""
                }`}
              >
                {/* Square Icon with rounded-2xl (16px) */}
                <div className="w-12 h-12 rounded-2xl bg-[#EDE9FE] flex items-center justify-center flex-shrink-0 group-hover:scale-105 transition-transform shadow-xs">
                  {feature.icon}
                </div>
                <div className="min-w-0">
                  <div className="text-[14px] sm:text-[15px] font-bold text-[#0F172A] leading-tight group-hover:text-[#5B21B6] transition-colors">
                    {feature.title}
                  </div>
                  <div className="text-xs text-gray-500 leading-normal mt-1">
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
