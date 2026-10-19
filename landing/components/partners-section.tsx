"use client";

import { useState } from "react";

export function PartnersSection() {
  const [partnerTab, setPartnerTab] = useState<"driver" | "merchant">("driver");
  const [submitted, setSubmitted] = useState(false);
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [city, setCity] = useState("Đà Nẵng");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!phone || !name) return;
    setSubmitted(true);
  };

  return (
    <section id="partners" className="py-20 sm:py-28 bg-[var(--color-canvas)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-2xl text-center">
          <span className="text-xs font-bold tracking-widest text-[var(--color-brand)] uppercase">
            Hợp tác cùng phát triển
          </span>
          <h2 className="mt-3 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl">
            Gia nhập hệ sinh thái đối tác{" "}
            <span className="whitespace-nowrap">
              <span className="text-[var(--color-brand)]">Deal</span>
              <span className="text-[var(--color-success)]">Go</span>
            </span>
          </h2>
          <p className="mt-4 text-base text-[var(--color-muted)]">
            Dù bạn là tài xế tìm kiếm nguồn thu nhập tự do hay chủ quán ăn muốn bùng nổ doanh số, DealGo luôn có giải pháp đồng hành cùng bạn.
          </p>


          {/* Toggle Tabs */}
          <div className="mt-8 inline-flex rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-1.5 shadow-sm">
            <button
              onClick={() => {
                setPartnerTab("driver");
                setSubmitted(false);
              }}
              className={`flex items-center gap-2 rounded-xl px-6 py-2.5 text-xs font-bold transition-all ${
                partnerTab === "driver"
                  ? "bg-[var(--color-brand)] text-white shadow-md shadow-purple-600/20"
                  : "text-[var(--color-muted)] hover:text-[var(--color-ink)]"
              }`}
            >
              <span>🛵</span>
              <span>Dành cho Tài xế</span>
            </button>
            <button
              onClick={() => {
                setPartnerTab("merchant");
                setSubmitted(false);
              }}
              className={`flex items-center gap-2 rounded-xl px-6 py-2.5 text-xs font-bold transition-all ${
                partnerTab === "merchant"
                  ? "bg-[var(--color-food)] text-white shadow-md shadow-orange-600/20"
                  : "text-[var(--color-muted)] hover:text-[var(--color-ink)]"
              }`}
            >
              <span>🍲</span>
              <span>Dành cho Quán ăn / Nhà hàng</span>
            </button>
          </div>
        </div>

        {/* Dynamic Partner Detail & Form */}
        <div className="mt-14 grid items-stretch gap-8 lg:grid-cols-12">
          {/* Left: Benefits & Information */}
          <div className="lg:col-span-7 flex flex-col justify-between rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-8 sm:p-10 shadow-sm">
            {partnerTab === "driver" ? (
              <div>
                <div className="flex items-center gap-3.5">
                  <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-purple-500/10 overflow-hidden border border-purple-500/20">
                    <img src="/assets/images/role_driver.png" alt="Tài xế DealGo" className="h-full w-full object-cover" />
                  </div>

                  <div>
                    <h3 className="text-2xl font-bold text-[var(--color-ink)]">
                      Tài xế công nghệ <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span>
                    </h3>
                    <p className="text-xs text-[var(--color-muted)]">Tự do làm chủ thời gian, tối ưu thu nhập mỗi cuốc xe</p>
                  </div>
                </div>


                <div className="mt-8 grid gap-5 sm:grid-cols-2">
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-brand)]">Chiết khấu tối ưu</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Mức phí nền tảng cực kỳ cạnh tranh, đảm bảo bạn nhận được phần lớn nhất giá trị chuyến xe.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-brand)]">Chủ động đàm phán giá</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Bạn có quyền phản hồi lại mức giá với khách hàng cho phù hợp với quãng đường và điều kiện giao thông.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-brand)]">Rút tiền trong ngày</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Thu nhập minh bạch, chuyển khoản tức thì về tài khoản ngân hàng liên kết mọi lúc bạn muốn.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-brand)]">Bảo hiểm trọn hành trình</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Mỗi cuốc xe hoàn thành đều được bảo hiểm tai nạn và hỗ trợ khẩn cấp 24/7 từ tổng đài DealGo.
                    </p>
                  </div>
                </div>
              </div>
            ) : (
              <div>
                <div className="flex items-center gap-3.5">
                  <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-orange-500/10 overflow-hidden border border-orange-500/20">
                    <img src="/assets/images/role_shop.png" alt="Đối tác Quán ăn DealGo" className="h-full w-full object-cover" />
                  </div>

                  <div>
                    <h3 className="text-2xl font-bold text-[var(--color-ink)]">
                      Đối tác Nhà hàng &amp; Quán ăn <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span>
                    </h3>
                    <p className="text-xs text-[var(--color-muted)]">Mở rộng tệp khách hàng, tiếp cận hàng ngàn đơn mỗi ngày</p>
                  </div>

                </div>

                <div className="mt-8 grid gap-5 sm:grid-cols-2">
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-food)]">0đ Phí khởi tạo</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Đăng ký gian hàng hoàn toàn miễn phí, hỗ trợ chụp ảnh menu và tối ưu hóa hình ảnh món ăn chuyên nghiệp.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-food)]">Đội ngũ Shipper hùng hậu</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Tài xế DealGo luôn sẵn sàng quanh khu vực của bạn, đảm bảo món ăn được lấy ngay khi vừa chế biến xong.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-food)]">Phần mềm quản lý đơn</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Tích hợp ngay trong App di động hoặc Web, nhận đơn tự động, báo cáo doanh thu theo từng ca bán.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-canvas)] p-5">
                    <p className="text-lg font-bold text-[var(--color-food)]">Hỗ trợ Marketing tăng đơn</p>
                    <p className="mt-1.5 text-xs text-[var(--color-muted)] leading-relaxed">
                      Tham gia các chương trình Flash Sale, freeship và chiến dịch thương hiệu lớn trên nền tảng.
                    </p>
                  </div>
                </div>
              </div>
            )}

            <div className="mt-8 rounded-2xl border border-dashed border-[var(--color-border)] p-4 text-xs text-[var(--color-muted)] flex items-center justify-between">
              <span>Hồ sơ xét duyệt nhanh chóng chỉ từ 24 - 48 giờ làm việc.</span>
              <span className="font-bold text-[var(--color-ink)]">Hotline: 1900 xxxx</span>
            </div>
          </div>

          {/* Right: Quick Registration Form */}
          <div className="lg:col-span-5 rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] p-8 sm:p-10 shadow-sm flex flex-col justify-center">
            {submitted ? (
              <div className="text-center py-10 space-y-4">
                <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600 text-3xl">
                  ✓
                </div>
                <h4 className="text-xl font-bold text-[var(--color-ink)]">Đăng ký thành công!</h4>
                <p className="text-xs text-[var(--color-muted)] max-w-xs mx-auto">
                  Cảm ơn bạn! Đội ngũ tư vấn đối tác của DealGo sẽ liên hệ trực tiếp qua số điện thoại <b>{phone}</b> trong vòng 24 giờ.
                </p>
                <button
                  onClick={() => setSubmitted(false)}
                  className="rounded-xl border border-[var(--color-border)] px-4 py-2 text-xs font-semibold text-[var(--color-ink)] hover:bg-[var(--color-canvas)]"
                >
                  Gửi thông tin khác
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-4.5">
                <div>
                  <h4 className="text-xl font-bold text-[var(--color-ink)]">
                    {partnerTab === "driver" ? (
                      <>Đăng ký làm Tài xế <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span></>
                    ) : (
                      <>Đăng ký mở Quán trên <span className="text-[var(--color-brand)]">Deal</span><span className="text-[var(--color-success)]">Go</span></>
                    )}
                  </h4>
                  <p className="mt-1 text-xs text-[var(--color-muted)]">

                    Điền thông tin cơ bản dưới đây để nhận tư vấn và hướng dẫn thủ tục miễn phí.
                  </p>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-[var(--color-ink)] mb-1.5">
                    Họ và tên của bạn
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Ví dụ: Nguyễn Văn Hùng"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-canvas)] px-3.5 py-2.5 text-xs text-[var(--color-ink)] placeholder-slate-400 focus:border-[var(--color-brand)] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-[var(--color-ink)] mb-1.5">
                    Số điện thoại liên hệ (Zalo)
                  </label>
                  <input
                    type="tel"
                    required
                    placeholder="Ví dụ: 0912 345 678"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-canvas)] px-3.5 py-2.5 text-xs text-[var(--color-ink)] placeholder-slate-400 focus:border-[var(--color-brand)] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-[var(--color-ink)] mb-1.5">
                    Khu vực bạn muốn hoạt động
                  </label>
                  <select
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-canvas)] px-3.5 py-2.5 text-xs text-[var(--color-ink)] focus:border-[var(--color-brand)] focus:outline-none"
                  >
                    <option value="Đà Nẵng">Đà Nẵng</option>
                    <option value="TP. Hồ Chí Minh">TP. Hồ Chí Minh</option>
                    <option value="Hà Nội">Hà Nội</option>
                    <option value="Khác">Khu vực khác</option>
                  </select>
                </div>

                <div className="pt-2">
                  <button
                    type="submit"
                    className={`w-full rounded-xl py-3 text-xs font-bold text-white shadow-md transition-all active:scale-98 ${
                      partnerTab === "driver"
                        ? "bg-[var(--color-brand)] hover:bg-[var(--color-brand-dark)] shadow-purple-600/25"
                        : "bg-[var(--color-food)] hover:bg-orange-700 shadow-orange-600/25"
                    }`}
                  >
                    Gửi yêu cầu đăng ký ngay
                  </button>
                  <p className="mt-2 text-center text-[10px] text-[var(--color-muted)]">
                    Bằng việc bấm gửi, bạn đồng ý với Quy chế hoạt động & Chính sách bảo mật của DealGo.
                  </p>
                </div>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
