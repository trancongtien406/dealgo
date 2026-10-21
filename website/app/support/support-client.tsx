"use client";

import { useState } from "react";
import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useSupportConfigQuery } from "@/features/content-cms/hooks";

export function SupportClient() {
  const { data: config, isPending } = useSupportConfigQuery();

  const [query, setQuery] = useState("");
  const [role, setRole] = useState("CUSTOMER");
  const [topic, setTopic] = useState("PAYMENT");
  const [contactName, setContactName] = useState("");
  const [refCode, setRefCode] = useState("");
  const [contact, setContact] = useState("");
  const [content, setContent] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [ticketCode, setTicketCode] = useState<string | null>(null);

  if (isPending || !config) {
    return (
      <div className="min-h-screen bg-canvas text-ink flex flex-col items-center justify-center p-4">
        <OpsIcon
          name="refresh"
          className="size-8 animate-spin text-brand mb-3"
        />
        <p className="text-sm font-medium text-muted">
          Đang tải thông tin hỗ trợ từ máy chủ DealGo...
        </p>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim() || !contact.trim()) return;

    setSubmitting(true);
    setSubmitError(null);

    try {
      const res = await fetch("/api/public/support", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          role,
          category: topic,
          refCode: refCode.trim() || undefined,
          contact: contact.trim(),
          contactName: contactName.trim() || undefined,
          content: content.trim(),
        }),
      });

      const json = (await res.json().catch(() => null)) as {
        success?: boolean;
        message?: string;
        data?: { ticketCode?: string };
      } | null;

      if (!res.ok || !json?.success) {
        setSubmitError(
          json?.message || "Không thể gửi yêu cầu hỗ trợ. Vui lòng thử lại.",
        );
        return;
      }

      if (!json.data?.ticketCode) {
        setSubmitError("Không thể gửi yêu cầu hỗ trợ. Vui lòng thử lại.");
        return;
      }
      setTicketCode(json.data.ticketCode);
      setSubmitted(true);
    } catch {
      setSubmitError(
        "Mất kết nối máy chủ. Vui lòng kiểm tra kết nối mạng hoặc gọi tổng đài.",
      );
    } finally {
      setSubmitting(false);
    }
  };

  const filteredCategories = config.categories.map((cat) => {
    if (!query.trim()) return cat;
    const q = query.trim().toLowerCase();
    return {
      ...cat,
      items: cat.items.filter((item) => item.toLowerCase().includes(q)),
    };
  });

  return (
    <div className="min-h-screen bg-canvas text-ink">
      {/* Top Header */}
      <header className="sticky top-0 z-30 border-b border-border bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link href="/overview" className="flex items-center gap-2">
            <BrandMark />
          </Link>
          <div className="flex items-center gap-3">
            <Link
              href="/settings/content"
              className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-brand/30 bg-brand/5 px-3 text-xs font-medium text-brand hover:bg-brand/10 transition-colors"
            >
              <OpsIcon name="settings" className="size-3.5" />
              Chỉnh sửa (Admin)
            </Link>
            <Link
              href="/login"
              className="inline-flex h-9 items-center rounded-lg bg-brand px-3 text-xs font-medium text-white hover:bg-brand/90 transition-colors"
            >
              Đăng nhập quản trị
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Header */}
      <section className="border-b border-border bg-gradient-to-b from-brand/5 via-white to-canvas px-4 py-12 text-center sm:px-6 sm:py-16">
        <div className="mx-auto max-w-3xl">
          <div className="inline-flex items-center gap-2 rounded-full border border-success/30 bg-success/10 px-3 py-1 text-xs font-medium text-success">
            <span className="size-2 rounded-full bg-success animate-pulse" />
            {config.systemStatusNotice ||
              "Hệ thống hỗ trợ DealGo trực tuyến 24/7"}
          </div>
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight sm:text-4xl text-ink">
            Chúng tôi có thể giúp gì cho bạn?
          </h1>
          <p className="mt-2 text-sm text-muted">
            Tra cứu thông tin giải đáp nhanh hoặc gửi yêu cầu trực tiếp đến đội
            ngũ Chăm sóc khách hàng DealGo.
          </p>

          {/* Search bar */}
          <div className="relative mx-auto mt-6 max-w-xl">
            <OpsIcon
              name="search"
              className="pointer-events-none absolute top-1/2 left-3.5 size-4.5 -translate-y-1/2 text-muted"
            />
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Nhập vấn đề bạn cần trợ giúp (VD: quên đồ, hoàn tiền, nạp ví...)"
              className="h-12 w-full rounded-2xl border border-border bg-white pr-4 pl-11 text-sm text-ink placeholder:text-muted shadow-sm focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20"
            />
          </div>
        </div>
      </section>

      {/* Support Categories */}
      <section className="mx-auto max-w-6xl px-4 py-10 sm:px-6 sm:py-12">
        <h2 className="text-xl font-bold text-ink">
          Chủ đề hỗ trợ theo vai trò
        </h2>
        <p className="mt-1 text-sm text-muted">
          Chọn nhóm chủ đề liên quan để nhận hướng dẫn chi tiết
        </p>

        <div className="mt-6 grid gap-6 md:grid-cols-3">
          {filteredCategories.map((cat) => (
            <div
              key={cat.title}
              className="rounded-2xl border border-border bg-white p-5 shadow-xs flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center gap-3">
                  <span
                    className={`grid size-10 place-items-center rounded-xl border ${cat.tone}`}
                  >
                    <OpsIcon name={cat.icon} className="size-5" />
                  </span>
                  <h3 className="font-bold text-ink">{cat.title}</h3>
                </div>
                <ul className="mt-4 space-y-2.5">
                  {cat.items.map((item, idx) => (
                    <li
                      key={idx}
                      className="flex items-start gap-2 text-xs text-muted"
                    >
                      <OpsIcon
                        name="chevron"
                        className="size-3.5 shrink-0 rotate-270 text-muted mt-0.5"
                      />
                      <span className="hover:text-brand cursor-pointer transition-colors">
                        {item}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
              <div className="mt-6 pt-4 border-t border-border">
                <a
                  href="#ticket-form"
                  onClick={() => {
                    if (cat.title.includes("Khách")) setRole("CUSTOMER");
                    if (cat.title.includes("Tài xế")) setRole("DRIVER");
                    if (cat.title.includes("Quán")) setRole("MERCHANT");
                  }}
                  className="text-xs font-semibold text-brand hover:underline inline-flex items-center gap-1"
                >
                  Gửi yêu cầu hỗ trợ nhóm này →
                </a>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Ticket / Support Request Form */}
      <section
        id="ticket-form"
        className="border-t border-border bg-white px-4 py-12 sm:px-6 sm:py-16"
      >
        <div className="mx-auto max-w-2xl">
          <div className="text-center">
            <span className="grid size-12 mx-auto place-items-center rounded-2xl bg-brand/10 text-brand">
              <OpsIcon name="headset" className="size-6" />
            </span>
            <h2 className="mt-3 text-2xl font-bold text-ink">
              Gửi thông tin phản ánh & Đóng góp ý kiến
            </h2>
            <p className="mt-1 text-sm text-muted">
              Đối với sự cố chuyến đi hoặc giao hàng khẩn cấp, vui lòng gọi Tổng
              đài <strong>{config.hotline}</strong> hoặc mở mục Trợ giúp trên
              ứng dụng DealGo để được xác thực tài khoản tức thì.
            </p>
          </div>

          {submitted ? (
            <div className="mt-8 rounded-2xl border border-success/30 bg-success/5 p-6 text-center space-y-4">
              <span className="grid size-12 mx-auto place-items-center rounded-full bg-success/20 text-success">
                <OpsIcon name="check" className="size-6" />
              </span>
              <div>
                <h3 className="text-lg font-bold text-ink">
                  Đã tạo yêu cầu hỗ trợ
                </h3>
                <p className="mt-2 text-sm text-muted">
                  Bộ phận hỗ trợ DealGo đã nhận yêu cầu và sẽ liên hệ lại qua
                  thông tin bạn cung cấp. Mã yêu cầu của bạn:
                </p>
                <div className="mt-2 inline-flex items-center gap-2 rounded-xl bg-white border border-border px-4 py-2 shadow-xs">
                  <span className="text-xs text-muted">Mã yêu cầu:</span>
                  <span className="font-mono text-base font-bold text-brand tracking-wider">
                    {ticketCode}
                  </span>
                </div>
              </div>
              <p className="text-xs text-muted max-w-lg mx-auto">
                Nếu cần bổ sung hình ảnh/chứng từ, hãy gửi kèm mã này qua hòm
                thư hỗ trợ hoặc đọc mã khi gọi tổng đài 24/7.
              </p>
              <div className="flex flex-wrap items-center justify-center gap-3 pt-2">
                <a
                  href={`mailto:${config.email}?subject=${encodeURIComponent(`[DealGo Hỗ trợ] [${ticketCode}] [${role}] [${topic}]${refCode ? ` - Mã đơn: ${refCode}` : ""}`)}&body=${encodeURIComponent(`Kính gửi Bộ phận CSKH DealGo,\n\nMã yêu cầu hỗ trợ của tôi: ${ticketCode}\nNhóm vấn đề: ${topic}\nVai trò: ${role}\nMã đơn/chuyến liên quan: ${refCode || "Không có"}\nThông tin liên hệ của tôi: ${contact}\n\nNội dung cần hỗ trợ:\n${content}\n\nRất mong được hỗ trợ xử lý sớm.\nTrân trọng!`)}`}
                  className="inline-flex h-10 items-center gap-1.5 rounded-xl bg-brand px-4 text-xs font-semibold text-white hover:bg-brand/90 transition-colors shadow-xs"
                >
                  <OpsIcon name="mail" className="size-4" />
                  Gửi bổ sung qua email kèm mã yêu cầu
                </a>
                <a
                  href={`tel:${config.hotline.replace(/\s+/g, "")}`}
                  className="inline-flex h-10 items-center gap-1.5 rounded-xl border border-border bg-white px-4 text-xs font-medium text-ink hover:bg-canvas transition-colors"
                >
                  <OpsIcon name="phone" className="size-3.5 text-danger" />
                  Gọi tổng đài {config.hotline}
                </a>
                <button
                  type="button"
                  onClick={() => {
                    setSubmitted(false);
                    setContent("");
                    setContact("");
                    setRefCode("");
                    setContactName("");
                    setTicketCode(null);
                  }}
                  className="inline-flex h-10 items-center rounded-xl border border-transparent px-3 text-xs font-medium text-muted hover:text-ink transition-colors cursor-pointer"
                >
                  Gửi yêu cầu khác
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="mt-8 space-y-4">
              {submitError ? (
                <div className="rounded-xl border border-danger/30 bg-danger/5 p-3 text-xs text-danger flex items-center gap-2">
                  <OpsIcon name="alert" className="size-4 shrink-0" />
                  <span>{submitError}</span>
                </div>
              ) : null}

              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label
                    htmlFor="sup-role"
                    className="block text-xs font-medium text-muted"
                  >
                    Bạn là:
                  </label>
                  <select
                    id="sup-role"
                    value={role}
                    onChange={(e) => setRole(e.target.value)}
                    className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                  >
                    <option value="CUSTOMER">Khách hàng đặt xe / đồ ăn</option>
                    <option value="DRIVER">Tài xế đối tác DealGo</option>
                    <option value="MERCHANT">Chủ quán ăn / Cửa hàng</option>
                    <option value="OTHER">Khác</option>
                  </select>
                </div>
                <div>
                  <label
                    htmlFor="sup-topic"
                    className="block text-xs font-medium text-muted"
                  >
                    Nhóm vấn đề:
                  </label>
                  <select
                    id="sup-topic"
                    value={topic}
                    onChange={(e) => setTopic(e.target.value)}
                    className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                  >
                    <option value="PAYMENT">Thanh toán & Hoàn tiền</option>
                    <option value="RIDE">Chuyến đi & Quên đồ</option>
                    <option value="FOOD">Đơn đồ ăn & Giao nhận</option>
                    <option value="ACCOUNT">Tài khoản & Xác minh KYC/KYB</option>
                    <option value="SAFETY">An toàn & Sự cố</option>
                    <option value="OTHER">Vấn đề khác</option>
                  </select>
                </div>
              </div>

              <div>
                <label
                  htmlFor="sup-contact"
                  className="block text-xs font-medium text-muted"
                >
                  Số điện thoại hoặc Email để DealGo liên hệ phản hồi{" "}
                  <span className="text-danger">*</span>:
                </label>
                <input
                  id="sup-contact"
                  type="text"
                  required
                  value={contact}
                  onChange={(e) => setContact(e.target.value)}
                  placeholder="Ví dụ: 0901234567 hoặc hotro@domain.vn"
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none"
                />
              </div>

              <div>
                <label
                  htmlFor="sup-name"
                  className="block text-xs font-medium text-muted"
                >
                  Tên của bạn (không bắt buộc):
                </label>
                <input
                  id="sup-name"
                  type="text"
                  maxLength={80}
                  value={contactName}
                  onChange={(e) => setContactName(e.target.value)}
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none"
                />
              </div>

              <div>
                <label
                  htmlFor="sup-ref"
                  className="block text-xs font-medium text-muted"
                >
                  Mã chuyến đi hoặc mã đơn hàng liên quan (nếu có):
                </label>
                <input
                  id="sup-ref"
                  type="text"
                  value={refCode}
                  onChange={(e) => setRefCode(e.target.value)}
                  placeholder="Ví dụ: RIDE-88421 hoặc FO-240610-0892"
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none"
                />
              </div>

              <div>
                <label
                  htmlFor="sup-desc"
                  className="block text-xs font-medium text-muted"
                >
                  Mô tả chi tiết vấn đề cần hỗ trợ (tối thiểu 10 ký tự){" "}
                  <span className="text-danger">*</span>:
                </label>
                <textarea
                  id="sup-desc"
                  rows={4}
                  required
                  minLength={10}
                  maxLength={2000}
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="Vui lòng mô tả cụ thể tình huống, thời gian xảy ra và yêu cầu cần trợ giúp..."
                  className="mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none"
                />
              </div>

              <div className="space-y-3 pt-1">
                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-brand text-sm font-semibold text-white hover:bg-brand/90 transition-colors shadow-sm disabled:opacity-50 cursor-pointer"
                >
                  {submitting ? (
                    <>
                      <OpsIcon name="refresh" className="size-4 animate-spin" />
                      Đang gửi yêu cầu...
                    </>
                  ) : (
                    "Gửi yêu cầu hỗ trợ"
                  )}
                </button>

                <div className="text-center">
                  <a
                    href={`mailto:${config.email}?subject=${encodeURIComponent(`[DealGo Hỗ trợ] [${role}] [${topic}]${refCode ? ` - Mã: ${refCode}` : ""}`)}&body=${encodeURIComponent(`Xin chào Bộ phận CSKH DealGo,\n\nTôi cần hỗ trợ về vấn đề sau:\n${content}\n\nThông tin liên hệ của tôi: ${contact}\nMã đơn/chuyến: ${refCode}`)}`}
                    className="text-xs text-muted hover:text-brand underline inline-flex items-center gap-1"
                  >
                    <OpsIcon name="mail" className="size-3" />
                    Hoặc mở ứng dụng thư gửi trực tiếp tới {config.email}
                  </a>
                </div>
              </div>
            </form>
          )}
        </div>
      </section>

      {/* Emergency Contact & Channels */}
      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-2xl border border-border bg-white p-5 text-center">
            <span className="grid size-10 mx-auto place-items-center rounded-xl bg-danger/10 text-danger">
              <OpsIcon name="phone" className="size-5" />
            </span>
            <h4 className="mt-2 font-bold text-ink">Tổng đài khẩn cấp 24/7</h4>
            <p className="mt-1 text-xs text-muted">
              Hỗ trợ các vấn đề sự cố trên đường
            </p>
            <p className="mt-2 text-base font-extrabold text-danger">
              {config.hotline}
            </p>
          </div>
          <div className="rounded-2xl border border-border bg-white p-5 text-center">
            <span className="grid size-10 mx-auto place-items-center rounded-xl bg-brand/10 text-brand">
              <OpsIcon name="mail" className="size-5" />
            </span>
            <h4 className="mt-2 font-bold text-ink">Hòm thư tiếp nhận</h4>
            <p className="mt-1 text-xs text-muted">
              Gửi hóa đơn, chứng từ bồi thường
            </p>
            <p className="mt-2 text-sm font-bold text-brand">{config.email}</p>
          </div>
          <div className="rounded-2xl border border-border bg-white p-5 text-center">
            <span className="grid size-10 mx-auto place-items-center rounded-xl bg-success/10 text-success">
              <OpsIcon name="shield" className="size-5" />
            </span>
            <h4 className="mt-2 font-bold text-ink">Chính sách & Quy định</h4>
            <p className="mt-1 text-xs text-muted">
              Tra cứu quyền lợi & trách nhiệm
            </p>
            <div className="mt-2 flex items-center justify-center gap-3 text-xs">
              <Link
                href="/terms"
                className="text-brand font-medium hover:underline"
              >
                Điều khoản
              </Link>
              <span>·</span>
              <Link
                href="/privacy"
                className="text-brand font-medium hover:underline"
              >
                Quyền riêng tư
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border bg-white px-4 py-8 text-center text-xs text-muted sm:px-6">
        <p>
          © {new Date().getFullYear()} DealGo Platform. Nền tảng điều phối vận
          tải & giao đồ ăn thông minh.
        </p>
      </footer>
    </div>
  );
}
