export default function HowItWorksSection() {
  const rideSteps = [
    {
      num: "1",
      title: "Nhập điểm đi, điểm đến",
      desc: "Chọn loại xe và đề xuất giá của bạn",
    },
    {
      num: "2",
      title: "Nhận báo giá",
      desc: "Tài xế xem và phản hồi mức giá",
    },
    {
      num: "3",
      title: "Chọn tài xế",
      desc: "Xem thông tin, đánh giá và chọn tài xế phù hợp",
    },
    {
      num: "4",
      title: "Bắt đầu chuyến đi",
      desc: "Theo dõi hành trình trực tiếp",
    },
  ];

  const foodSteps = [
    {
      num: "1",
      title: "Chọn quán và món",
      desc: "Khám phá hàng ngàn quán ăn, cửa hàng gần bạn",
    },
    {
      num: "2",
      title: "Đặt đơn",
      desc: "Xác nhận đơn hàng và chọn phương thức thanh toán",
    },
    {
      num: "3",
      title: "Quán chuẩn bị và tìm tài xế",
      desc: "Theo dõi trạng thái đơn hàng",
    },
    {
      num: "4",
      title: "Nhận hàng",
      desc: "Nhận món và thưởng thức tại nhà",
    },
  ];

  return (
    <section id="cach-hoat-dong" className="pt-4 sm:pt-6 pb-4 sm:pb-6 bg-white scroll-mt-24">
      <div className="max-w-[1500px] mx-auto px-4 sm:px-8 lg:px-12">
        {/* Section Header */}
        <div className="flex flex-wrap items-baseline gap-3 mb-4 sm:mb-5">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-[#2E1065] tracking-tight">
            Cách hoạt động
          </h2>
          <p className="text-xs sm:text-sm text-gray-500 font-normal">
            Chỉ với vài bước đơn giản, bạn có thể đặt xe hoặc đặt đồ ăn trên DealGo.
          </p>
        </div>

        {/* 2 Process Panels Grid */}
        <div className="grid lg:grid-cols-2 gap-6 lg:gap-8">
          {/* Panel 1: Quy trình đặt xe */}
          <div className="bg-white rounded-[28px] p-5 sm:p-7 border border-purple-100 shadow-[0_4px_20px_-4px_rgba(109,40,217,0.06)]">
            {/* Panel Header */}
            <div className="flex items-center justify-between pb-5 border-b border-gray-100 mb-5">
              <div className="flex items-center gap-2.5">
                <svg className="w-5 h-5 text-[#6D28D9]" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" />
                </svg>
                <h3 className="font-bold text-[#0F172A] text-base sm:text-lg">
                  Quy trình đặt xe
                </h3>
              </div>
              <span className="text-xs font-semibold text-[#6D28D9] bg-[#EDE9FE] px-3 py-1 rounded-full border border-purple-200/50">
                4 bước đơn giản
              </span>
            </div>

            {/* 4 Steps Horizontal Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 sm:gap-3">
              {rideSteps.map((step) => (
                <div
                  key={step.num}
                  className="bg-[#F9F8FD] rounded-2xl p-3.5 sm:p-4 flex flex-col items-center text-center transition-all duration-200 hover:bg-[#F3EFFE]"
                >
                  <div className="w-7 h-7 rounded-full bg-[#6D28D9] text-white font-bold flex items-center justify-center text-xs mb-3 shadow-xs">
                    {step.num}
                  </div>
                  <div className="font-bold text-[#0F172A] text-xs sm:text-[13px] leading-tight min-h-[32px] flex items-center">
                    {step.title}
                  </div>
                  <div className="text-[11px] text-gray-500 leading-normal mt-1.5">
                    {step.desc}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Panel 2: Quy trình đặt đồ ăn */}
          <div className="bg-white rounded-[28px] p-5 sm:p-7 border border-emerald-100 shadow-[0_4px_20px_-4px_rgba(0,208,108,0.06)]">
            {/* Panel Header */}
            <div className="flex items-center justify-between pb-5 border-b border-gray-100 mb-5">
              <div className="flex items-center gap-2.5">
                <svg className="w-5 h-5 text-[#00D06C]" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-1.99.9-1.99 2L3 20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm0 10c-2.76 0-5-2.24-5-5h2c0 1.66 1.34 3 3 3s3-1.34 3-3h2c0 2.76-2.24 5-5 5z" />
                </svg>
                <h3 className="font-bold text-[#0F172A] text-base sm:text-lg">
                  Quy trình đặt đồ ăn
                </h3>
              </div>
              <span className="text-xs font-semibold text-[#6D28D9] bg-[#EDE9FE] px-3 py-1 rounded-full border border-purple-200/50">
                4 bước đơn giản
              </span>
            </div>

            {/* 4 Steps Horizontal Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 sm:gap-3">
              {foodSteps.map((step) => (
                <div
                  key={step.num}
                  className="bg-[#F9F8FD] rounded-2xl p-3.5 sm:p-4 flex flex-col items-center text-center transition-all duration-200 hover:bg-[#F3EFFE]"
                >
                  <div className="w-7 h-7 rounded-full bg-[#6D28D9] text-white font-bold flex items-center justify-center text-xs mb-3 shadow-xs">
                    {step.num}
                  </div>
                  <div className="font-bold text-[#0F172A] text-xs sm:text-[13px] leading-tight min-h-[32px] flex items-center">
                    {step.title}
                  </div>
                  <div className="text-[11px] text-gray-500 leading-normal mt-1.5">
                    {step.desc}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
