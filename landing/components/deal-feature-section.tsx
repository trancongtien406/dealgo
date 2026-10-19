"use client";

import { useState } from "react";

export function DealFeatureSection() {
  const [activeStep, setActiveStep] = useState(1);

  const steps = [
    {
      num: 1,
      tag: "Bước 1",
      title: "Đề xuất mức giá bạn mong muốn",
      desc: "Thay vì bị ép mức giá tăng đột biến vào giờ cao điểm hay ngày mưa, bạn có thể tự nhập hoặc chọn gợi ý giá mong muốn khi đặt xe hoặc giao hàng.",
      action: "Khách đưa giá: 35.000 đ",
      icon: "💬",
    },
    {
      num: 2,
      tag: "Bước 2",
      title: "Tài xế xem xét và phản hồi tức thì",
      desc: "Các tài xế trong bán kính gần nhất sẽ nhận được đề xuất. Họ có thể nhận ngay lập tức hoặc phản hồi lại mức giá thương lượng mong muốn.",
      action: "Tài xế phản hồi: 38.000 đ",
      icon: "🤝",
    },
    {
      num: 3,
      tag: "Bước 3",
      title: "Đồng thuận & Khởi hành an tâm",
      desc: "Hai bên thống nhất mức giá chốt. Giá tiền được niêm yết cố định trên ứng dụng và không phát sinh bất kỳ khoản phụ phí ẩn nào.",
      action: "Chốt deal thành công: 36.000 đ",
      icon: "🎉",
    },
  ];

  return (
    <section id="deal-feature" className="relative overflow-hidden py-20 sm:py-28 bg-[var(--color-canvas)] border-y border-[var(--color-border)]">
      {/* Decorative gradients */}
      <div className="pointer-events-none absolute top-1/2 left-0 -translate-y-1/2 -z-10 h-72 w-72 rounded-full bg-purple-500/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 right-0 -z-10 h-80 w-80 rounded-full bg-orange-500/10 blur-3xl" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid items-center gap-12 lg:grid-cols-12 lg:gap-16">
          {/* Left Text Explanation */}
          <div className="lg:col-span-6">
            <div className="inline-flex items-center gap-2 rounded-full bg-orange-500/10 px-3.5 py-1 text-xs font-bold text-orange-600 dark:text-orange-400">
              <span>Độc quyền tại <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span></span>
            </div>


            <h2 className="mt-4 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl">
              Cơ chế Deal Giá: <br className="hidden sm:inline" />
              Công bằng cho Khách, <br className="hidden sm:inline" />
              Tôn trọng Tài xế.
            </h2>

            <p className="mt-4 text-base text-[var(--color-muted)] leading-relaxed">
              Chúng tôi tin rằng sự minh bạch và thỏa thuận tự nguyện tạo nên một cộng đồng di chuyển bền vững. Không có thuật toán tăng giá ẩn, không có sự áp đặt một chiều.
            </p>

            {/* Steps Accordion */}
            <div className="mt-8 space-y-4">
              {steps.map((s) => (
                <div
                  key={s.num}
                  onClick={() => setActiveStep(s.num)}
                  className={`cursor-pointer rounded-2xl border p-5 transition-all ${
                    activeStep === s.num
                      ? "border-[var(--color-brand)] bg-[var(--color-canvas-card)] shadow-md shadow-purple-600/5"
                      : "border-[var(--color-border)] bg-[var(--color-canvas)]/50 hover:border-slate-300 dark:hover:border-slate-700"
                  }`}
                >
                  <div className="flex items-start gap-4">
                    <div
                      className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-lg font-bold transition-colors ${
                        activeStep === s.num
                          ? "bg-[var(--color-brand)] text-white shadow-sm"
                          : "bg-[var(--color-border)]/50 text-[var(--color-muted)]"
                      }`}
                    >
                      {s.icon}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center justify-between">
                        <h4 className="text-sm font-bold text-[var(--color-ink)]">{s.title}</h4>
                        <span className="text-[10px] font-semibold text-[var(--color-brand)] uppercase">
                          {s.tag}
                        </span>
                      </div>
                      <p className="mt-1 text-xs text-[var(--color-muted)] leading-relaxed">{s.desc}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Right Visual Comparison Card */}
          <div className="lg:col-span-6">
            <div className="rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-6 sm:p-8 shadow-xl">
              <div className="flex items-center justify-between border-b border-[var(--color-border)] pb-4">
                <div>
                  <h3 className="text-lg font-bold text-[var(--color-ink)]">So sánh trải nghiệm</h3>
                  <p className="text-xs text-[var(--color-muted)]">DealGo vs. Ứng dụng truyền thống</p>
                </div>
                <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-bold text-emerald-600">
                  Lợi ích vượt trội
                </span>
              </div>

              <div className="mt-6 space-y-5">
                {/* Traditional Model */}
                <div className="rounded-2xl border border-rose-200/60 bg-rose-50/40 p-4 dark:border-rose-950 dark:bg-rose-950/20">
                  <div className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400">
                    <span>✕</span>
                    <span>Ứng dụng gọi xe thông thường</span>
                  </div>
                  <ul className="mt-2.5 space-y-2 text-xs text-slate-600 dark:text-slate-400">
                    <li className="flex items-start gap-2">
                      <span className="text-rose-500">•</span>
                      <span>Thuật toán tự động tăng giá gấp 2x - 3x khi trời mưa hoặc giờ cao điểm</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-rose-500">•</span>
                      <span>Khách hàng không thể thương lượng, bắt buộc chấp nhận hoặc huỷ tìm xe</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-rose-500">•</span>
                      <span>Tài xế bị ép cuốc hoặc nhận chiết khấu cao mà không chủ động được giá</span>
                    </li>
                  </ul>
                </div>

                {/* DealGo Model */}
                <div className="rounded-2xl border border-purple-200 bg-purple-50/50 p-4 dark:border-purple-900/60 dark:bg-purple-950/30">
                  <div className="flex items-center gap-2 text-xs font-bold">
                    <span className="text-emerald-500">✓</span>
                    <span>Nền tảng <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span></span>
                  </div>

                  <ul className="mt-2.5 space-y-2 text-xs text-slate-700 dark:text-slate-300 font-medium">
                    <li className="flex items-start gap-2">
                      <span className="text-[var(--color-brand)]">•</span>
                      <span>Khách hàng & Tài xế tự do thương lượng mức giá đôi bên cùng có lợi</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-[var(--color-brand)]">•</span>
                      <span>Mức giá chốt minh bạch, hiển thị rõ ràng trên hóa đơn điện tử</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-[var(--color-brand)]">•</span>
                      <span>Chiết khấu nền tảng cạnh tranh nhất thị trường, tối đa hóa thu nhập cho tài xế</span>
                    </li>
                  </ul>
                </div>
              </div>

              {/* Callout */}
              <div className="mt-6 flex items-center justify-between rounded-xl bg-[var(--color-canvas)] p-3 text-xs border border-[var(--color-border)]">
                <span className="text-[var(--color-muted)]">Muốn thử ngay chuyến đi đầu tiên?</span>
                <a href="#download" className="font-bold hover:underline">
                  Tải <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span> ngay →
                </a>

              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
