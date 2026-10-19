"use client";

import Image from "next/image";

export function ServicesSection() {
  const services = [
    {
      id: "ride",
      badge: "Di chuyển xe 2 bánh",
      badgeColor: "bg-purple-500/10 text-purple-600 dark:text-purple-400 border border-purple-500/20",
      serviceName: "Ride",
      serviceNameColor: "text-[var(--color-brand)]",
      subtitle: "Gọi xe hai bánh linh hoạt & an toàn",
      description:
        "Di chuyển tiện lợi mọi ngõ ngách đô thị. Bạn có thể chọn giá cố định hoặc dùng tính năng Deal Giá để thỏa thuận mức giá hợp lý nhất cùng tài xế.",
      image: "/assets/svg/card_ride.svg",
      highlights: ["Ghép xe thần tốc trong 2 phút", "Biết trước lộ trình & thông tin tài xế", "Bảo hiểm chuyến đi 100%"],
      action: "Khám phá Ride",
      accentBg: "from-purple-500/5 to-purple-500/0",
    },
    {
      id: "food",
      badge: "Giao đồ ăn nóng sốt",
      badgeColor: "bg-orange-500/10 text-orange-600 dark:text-orange-400 border border-orange-500/20",
      serviceName: "Food",
      serviceNameColor: "text-[var(--color-food)]",
      subtitle: "Món ngon tận nơi từ quán quen",
      description:
        "Thưởng thức trọn vẹn ẩm thực từ quán quen lề đường đến nhà hàng cao cấp. Đóng gói cẩn thận, theo dõi đơn hàng từng phút trên bản đồ.",
      image: "/assets/svg/card_food.svg",
      highlights: ["Hơn 12.000+ quán ngon tuyển chọn", "Giao nhanh chỉ từ 15-25 phút", "Ưu đãi voucher mỗi ngày"],
      action: "Khám phá Food",
      accentBg: "from-orange-500/5 to-orange-500/0",
    },
    {
      id: "delivery",
      badge: "Giao nhận hỏa tốc",
      badgeColor: "bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20",
      serviceName: "Delivery",
      serviceNameColor: "text-[var(--color-delivery)]",
      subtitle: "Giao hàng bưu phẩm nội thành",
      description:
        "Chuyển phát tài liệu, hồ sơ, quà tặng cấp tốc trong ngày. Tài xế nhận hàng tận nơi và giao trực tiếp đến tay người nhận với mã xác nhận OTP.",
      image: "/assets/svg/card_delivery.svg",
      highlights: ["Giao nhận đa điểm tiện lợi", "Xác nhận giao hàng bằng ảnh & OTP", "Đền bù thiệt hại khi có sự cố"],
      action: "Khám phá Delivery",
      accentBg: "from-blue-500/5 to-blue-500/0",
    },
  ];

  return (
    <section id="services" className="py-20 sm:py-28">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-2xl text-center">
          <span className="text-xs font-bold tracking-widest text-[var(--color-brand)] uppercase">
            Hệ sinh thái dịch vụ
          </span>
          <h2 className="mt-3 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl">
            Một ứng dụng duy nhất, trọn vẹn mọi nhu cầu
          </h2>
          <p className="mt-4 text-base text-[var(--color-muted)]">
            Dù bạn cần đi làm mỗi sáng, đặt bữa trưa cho cả văn phòng hay gửi gói hàng gấp cho đối tác, DealGo luôn sẵn sàng phục vụ với mức giá công bằng nhất.
          </p>
        </div>

        <div className="mt-16 grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          {services.map((item) => (
            <div
              key={item.id}
              className="glass-card flex flex-col justify-between overflow-hidden rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] hover:border-[var(--color-brand)] transition-all shadow-sm hover:shadow-xl"
            >
              <div>
                {/* Visual Banner Header */}
                <div className="relative aspect-[16/9] w-full overflow-hidden bg-slate-100 dark:bg-slate-900 border-b border-[var(--color-border)]">
                  <img
                    src={item.image}
                    alt={item.subtitle}
                    className="h-full w-full object-cover transition-transform duration-500 hover:scale-105"
                  />
                  <div className="absolute top-3.5 left-3.5">
                    <span className={`rounded-full px-3 py-1 text-xs font-bold shadow-xs backdrop-blur-md ${item.badgeColor}`}>
                      {item.badge}
                    </span>
                  </div>
                </div>

                <div className="p-7">
                  <div className="flex items-center gap-1.5 text-2xl font-black tracking-tight">
                    <span className="text-[var(--color-brand)]">Deal</span>
                    <span className="text-[var(--color-success)]">Go</span>
                    <span className={`ml-1 ${item.serviceNameColor}`}>{item.serviceName}</span>
                  </div>
                  <p className="mt-1 text-xs font-semibold text-[var(--color-muted)]">{item.subtitle}</p>
                  <p className="mt-3.5 text-xs text-[var(--color-muted)] leading-relaxed">{item.description}</p>

                  {/* Highlights List */}
                  <div className="mt-6 space-y-2.5 border-t border-[var(--color-border)] pt-5">
                    {item.highlights.map((h, i) => (
                      <div key={i} className="flex items-center gap-2.5 text-xs text-[var(--color-ink)] font-medium">
                        <div className="flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600 font-bold text-[10px]">
                          ✓
                        </div>
                        <span>{h}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Bottom Card CTA */}
              <div className="p-7 pt-0">
                <a
                  href="#download"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-canvas)] py-3 text-xs font-bold text-[var(--color-ink)] transition-all hover:border-[var(--color-brand)] hover:text-[var(--color-brand)] hover:bg-[var(--color-brand)]/5"
                >
                  <span>{item.action}</span>
                  <span>→</span>
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
