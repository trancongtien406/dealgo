import Image from "next/image";

export default function ServicesSection() {
  const rideFeatures = [
    "Chủ động thương lượng giá với tài xế",
    "Xe máy (Bike), ô tô 4 chỗ và 7 chỗ (Car)",
    "Theo dõi hành trình trực tiếp",
    "Tiền mặt hoặc thanh toán trực tuyến",
  ];

  const foodFeatures = [
    "Món ăn, đồ uống từ quán và cửa hàng gần bạn",
    "Giao hàng nhanh, theo dõi trực tiếp",
    "Ưu đãi từ quán và mã giảm giá",
    "Chat, gọi với quán và tài xế giao hàng",
  ];

  return (
    <section id="dich-vu" className="pt-7 sm:pt-9 pb-4 sm:pb-5 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="mb-5 sm:mb-6">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Dịch vụ chính của Deal<span className="text-[#00D06C]">Go</span>
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 mt-1 font-normal">
            Đặt xe (Bike, Car) và đặt đồ ăn (Food) — tất cả trong một ứng dụng.
          </p>
        </div>

        {/* 2 Service Cards Grid */}
        <div className="grid lg:grid-cols-2 gap-6 lg:gap-8">
          {/* Card 1: Đặt xe */}
          <div id="dat-xe" className="scroll-mt-24 bg-gradient-to-br from-[#F5F3FF] via-[#EDE9FE]/50 to-[#F5F3FF] border border-purple-100 rounded-[28px] overflow-hidden shadow-sm hover:shadow-md transition-all duration-300 grid sm:grid-cols-12 items-center">
            {/* Left Content */}
            <div className="sm:col-span-7 p-6 sm:p-7 space-y-4">
              {/* Header */}
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-full bg-[#6D28D9] flex items-center justify-center text-white flex-shrink-0 shadow-md">
                  <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-[#0F172A] leading-tight">Đặt xe</h3>
                  <p className="text-xs text-gray-500 leading-tight mt-0.5">
                    Đi muôn nơi an toàn, tiện lợi với mức giá bạn đề xuất.
                  </p>
                </div>
              </div>

              {/* Checklist */}
              <ul className="space-y-2 pt-1">
                {rideFeatures.map((item, idx) => (
                  <li key={idx} className="flex items-center gap-2.5">
                    <span className="w-4 h-4 rounded-full bg-[#00D06C]/15 text-[#00D06C] flex items-center justify-center flex-shrink-0 font-bold text-[10px]">
                      ✔
                    </span>
                    <span className="text-xs sm:text-[13px] text-gray-700 font-medium">
                      {item}
                    </span>
                  </li>
                ))}
              </ul>

              {/* Button */}
              <div className="pt-2">
                <a
                  href="#cach-hoat-dong"
                  className="inline-flex items-center gap-1.5 bg-[#6D28D9] hover:bg-[#581C87] text-white text-xs sm:text-sm font-semibold px-5 py-2.5 rounded-2xl shadow-md shadow-purple-600/25 transition-all duration-200"
                >
                  <span>Xem quy trình đặt xe</span>
                  <span>→</span>
                </a>
              </div>
            </div>

            {/* Right Image */}
            <div className="sm:col-span-5 h-[230px] sm:h-full min-h-[220px] relative overflow-hidden rounded-b-[28px] sm:rounded-b-none sm:rounded-r-[28px]">
              <Image
                src="/landing/service_car.jpg"
                alt="Dịch vụ đặt xe DealGo"
                fill
                sizes="(max-width: 640px) 100vw, 320px"
                className="object-cover object-center"
              />
            </div>
          </div>

          {/* Card 2: Đồ ăn */}
          <div id="do-an" className="scroll-mt-24 bg-gradient-to-br from-[#F0FDF4] via-[#ECFDF5]/60 to-[#F5F3FF]/40 border border-emerald-100 rounded-[28px] overflow-hidden shadow-sm hover:shadow-md transition-all duration-300 grid sm:grid-cols-12 items-center">
            {/* Left Content */}
            <div className="sm:col-span-7 p-6 sm:p-7 space-y-4">
              {/* Header */}
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-full bg-[#00D06C] flex items-center justify-center text-white flex-shrink-0 shadow-md">
                  <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-1.99.9-1.99 2L3 20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm0 10c-2.76 0-5-2.24-5-5h2c0 1.66 1.34 3 3 3s3-1.34 3-3h2c0 2.76-2.24 5-5 5z" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-[#0F172A] leading-tight">Đồ ăn</h3>
                  <p className="text-xs text-gray-500 leading-tight mt-0.5">
                    Quán ăn, cửa hàng gần bạn giao tận nơi.
                  </p>
                </div>
              </div>

              {/* Checklist */}
              <ul className="space-y-2 pt-1">
                {foodFeatures.map((item, idx) => (
                  <li key={idx} className="flex items-center gap-2.5">
                    <span className="w-4 h-4 rounded-full bg-[#00D06C]/15 text-[#00D06C] flex items-center justify-center flex-shrink-0 font-bold text-[10px]">
                      ✔
                    </span>
                    <span className="text-xs sm:text-[13px] text-gray-700 font-medium">
                      {item}
                    </span>
                  </li>
                ))}
              </ul>

              {/* Button */}
              <div className="pt-2">
                <a
                  href="#cach-hoat-dong"
                  className="inline-flex items-center gap-1.5 bg-white hover:bg-purple-50 text-[#6D28D9] border-2 border-[#6D28D9]/30 text-xs sm:text-sm font-semibold px-5 py-2.5 rounded-2xl shadow-xs transition-all duration-200"
                >
                  <span>Xem quy trình đặt đồ ăn</span>
                  <span>→</span>
                </a>
              </div>
            </div>

            {/* Right Image */}
            <div className="sm:col-span-5 h-[230px] sm:h-full min-h-[220px] relative overflow-hidden rounded-b-[28px] sm:rounded-b-none sm:rounded-r-[28px]">
              <Image
                src="/landing/service_food.jpg"
                alt="Dịch vụ đặt đồ ăn DealGo"
                fill
                sizes="(max-width: 640px) 100vw, 320px"
                className="object-cover object-center"
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
