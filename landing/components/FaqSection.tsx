"use client";

import { useState } from "react";

const faqs = [
  {
    q: "DealGo là gì?",
    a: "DealGo là nền tảng ứng dụng đa dịch vụ kết hợp đặt xe hai bánh và giao đồ ăn, nổi bật với tính năng thương lượng giá trực tiếp linh hoạt và công bằng giữa khách hàng, tài xế và đối tác quán ăn.",
  },
  {
    q: "Làm sao để thương lượng giá khi đặt xe?",
    a: "Sau khi nhập điểm đón và điểm đến, bạn có thể tự chọn hoặc điều chỉnh mức giá mong muốn. Các tài xế gần bạn sẽ nhận thông tin và phản hồi ngay lập tức để bạn lựa chọn chuyến xe phù hợp nhất.",
  },
  {
    q: "Thời gian giao đồ ăn thường mất bao lâu?",
    a: "Thời gian giao hàng trung bình từ 15–30 phút tùy khoảng cách và thời gian chuẩn bị của quán. Bạn có thể theo dõi lộ trình di chuyển của tài xế theo thời gian thực trên bản đồ ứng dụng.",
  },
  {
    q: "Tôi có thể thanh toán bằng những phương thức nào?",
    a: "DealGo hỗ trợ đa dạng phương thức thanh toán an toàn bao gồm: Tiền mặt khi nhận hàng/hoàn thành chuyến, Ví điện tử (MoMo, ZaloPay, ShopeePay), thẻ ngân hàng nội địa Napas và thẻ quốc tế Visa/Mastercard.",
  },
  {
    q: "Làm sao để trở thành đối tác quán ăn hoặc tài xế?",
    a: "Bạn chỉ cần chọn mục 'Đăng ký quán ngay' hoặc 'Trở thành tài xế' trên ứng dụng/website DealGo, điền thông tin và tải lên các giấy tờ cần thiết. Đội ngũ DealGo sẽ liên hệ xác minh và hỗ trợ kích hoạt tài khoản trong vòng 24 giờ.",
  },
];

export default function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <div className="bg-white rounded-[24px] p-5 sm:p-6 border border-gray-100 shadow-[0_4px_24px_-4px_rgba(0,0,0,0.03)] h-full flex flex-col justify-between">
      {/* Header with Title and Inline Subtext */}
      <div className="flex flex-wrap items-baseline gap-2 mb-4 pb-2 border-b border-gray-100">
        <h3 className="text-base sm:text-lg font-extrabold text-[#2E1065] tracking-tight">
          Câu hỏi thường gặp
        </h3>
        <span className="text-xs text-gray-500 font-normal">
          Giải đáp một số thắc mắc phổ biến về DealGo.
        </span>
      </div>

      {/* Accordion List */}
      <div className="divide-y divide-gray-100 flex-1">
        {faqs.map((faq, i) => {
          const isOpen = openIndex === i;
          return (
            <div key={i} className="py-2.5 sm:py-3 transition-colors">
              <button
                type="button"
                className="w-full flex items-center justify-between text-left gap-3 group cursor-pointer"
                onClick={() => setOpenIndex(isOpen ? null : i)}
                aria-expanded={isOpen}
              >
                <span
                  className={`text-xs sm:text-[13px] font-medium transition-colors ${
                    isOpen ? "text-[#6D28D9] font-semibold" : "text-[#1E293B] group-hover:text-[#6D28D9]"
                  }`}
                >
                  {faq.q}
                </span>

                <span
                  className={`text-gray-400 group-hover:text-[#6D28D9] text-xs transition-transform duration-200 ${
                    isOpen ? "rotate-90 text-[#6D28D9]" : ""
                  }`}
                >
                  ›
                </span>
              </button>

              {isOpen && (
                <div className="mt-2 text-xs text-gray-500 leading-relaxed pr-4 animate-fadeIn">
                  {faq.a}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
