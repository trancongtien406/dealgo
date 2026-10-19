"use client";

import { useState } from "react";

export function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const faqs = [
    {
      q: "Tính năng Deal Giá hoạt động như thế nào? Tôi có bắt buộc phải trả giá không?",
      a: "Không bắt buộc! Bạn luôn có thể chọn mức giá niêm yết tiêu chuẩn của hệ thống để đặt xe nhanh như thông thường. Tính năng Deal Giá là lựa chọn linh hoạt cho phép bạn đề xuất mức giá mong muốn (ví dụ vào giờ cao điểm, thời tiết xấu hoặc các tuyến đường xa), giúp tài xế và khách hàng dễ dàng tìm thấy tiếng nói chung.",
    },
    {
      q: "DealGo hỗ trợ những phương thức thanh toán nào?",
      a: "DealGo hỗ trợ đa dạng phương thức: Tiền mặt trực tiếp (COD), Ví điện tử (MoMo, ZaloPay), chuyển khoản ngân hàng qua VietQR và thẻ thanh toán quốc tế Visa/Mastercard. Tất cả giao dịch đều được ghi nhận minh bạch trên hóa đơn điện tử.",
    },
    {
      q: "Đăng ký làm đối tác tài xế cần những giấy tờ gì và mất bao lâu để kích hoạt?",
      a: "Bạn chỉ cần chuẩn bị: Căn cước công dân (CCCD), Giấy phép lái xe (GPLX), Đăng ký xe (Cà vẹt) và Bảo hiểm xe máy còn hạn. Toàn bộ quy trình nộp hồ sơ được thực hiện online ngay trên ứng dụng DealGo và được xét duyệt trong vòng 24 - 48 giờ làm việc.",
    },
    {
      q: "Quán ăn đăng ký gian hàng trên DealGo Food có mất phí duy trì hàng tháng không?",
      a: "Hoàn toàn không! DealGo miễn phí 100% phí đăng ký khởi tạo gian hàng và không thu bất kỳ phí duy trì hàng tháng nào. Chúng tôi chỉ áp dụng mức chiết khấu dịch vụ công bằng trên từng đơn hàng thực tế phát sinh thành công.",
    },
    {
      q: "Nếu có sự cố phát sinh trong chuyến đi hoặc giao hàng, tôi được hỗ trợ ra sao?",
      a: "DealGo có đội ngũ Chăm sóc khách hàng và Trung tâm an toàn (SOS) túc trực 24/7. Bạn có thể nhấn nút khiếu nại trực tiếp trên cuốc xe trong App hoặc liên hệ hotline khẩn cấp để được bảo vệ quyền lợi và xử lý đền bù theo quy chuẩn.",
    },
  ];

  return (
    <section id="faq" className="py-20 sm:py-28 bg-[var(--color-canvas)]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <span className="text-xs font-bold tracking-widest text-[var(--color-brand)] uppercase">
            Giải đáp thắc mắc
          </span>
          <h2 className="mt-3 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl">
            Câu hỏi thường gặp về{" "}
            <span className="whitespace-nowrap">
              <span className="text-[var(--color-brand)]">Deal</span>
              <span className="text-[var(--color-success)]">Go</span>
            </span>
          </h2>
          <p className="mt-4 text-sm text-[var(--color-muted)]">

            Những điều bạn cần biết khi bắt đầu sử dụng dịch vụ hoặc tham gia làm đối tác.
          </p>
        </div>

        <div className="mt-12 space-y-3.5">
          {faqs.map((faq, idx) => (
            <div
              key={idx}
              className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] transition-colors overflow-hidden"
            >
              <button
                onClick={() => setOpenIndex(openIndex === idx ? null : idx)}
                className="flex w-full items-center justify-between p-5 text-left text-sm font-bold text-[var(--color-ink)] hover:text-[var(--color-brand)]"
              >
                <span>{faq.q}</span>
                <span className="ml-4 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--color-border)] text-xs font-bold">
                  {openIndex === idx ? "−" : "+"}
                </span>
              </button>

              {openIndex === idx && (
                <div className="border-t border-[var(--color-border)]/60 px-5 pt-3 pb-5 text-xs text-[var(--color-muted)] leading-relaxed">
                  {faq.a}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
