"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

const features = [
  {
    title: "Xác minh an toàn",
    detail: "Gửi mã OTP hoặc liên kết đặt lại tới tài khoản đã đăng ký",
    icon: "shield" as const,
    tone: "bg-brand/10 text-brand",
  },
  {
    title: "Khôi phục nhanh",
    detail: "Hoàn tất chỉ với vài bước đơn giản",
    icon: "trend" as const,
    tone: "bg-success/10 text-success",
  },
  {
    title: "Hỗ trợ 24/7",
    detail: "Đội ngũ kỹ thuật luôn sẵn sàng hỗ trợ",
    icon: "headset" as const,
    tone: "bg-brand/10 text-brand",
  },
] as const;

export default function ForgotPasswordPage() {
  const [account, setAccount] = useState("");
  const [notice, setNotice] = useState("");
  const [sent, setSent] = useState(false);

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (account.trim() === "") {
      setNotice("Nhập email hoặc số điện thoại.");
      setSent(false);
      return;
    }
    setNotice("");
    setSent(true);
  }

  return (
    <main className="relative flex min-h-svh flex-col overflow-x-clip px-4 py-8 sm:px-6 sm:py-12">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -top-24 -left-20 size-80 rounded-full bg-brand/10 blur-3xl"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute right-0 bottom-0 size-72 rounded-full bg-brand/5 blur-3xl"
      />
      <section className="relative m-auto grid w-full max-w-6xl overflow-hidden rounded-[28px] border border-border bg-white shadow-[0_24px_70px_rgba(109,40,217,0.08)] lg:grid-cols-2">
        <div className="relative hidden flex-col overflow-hidden bg-brand/5 px-8 py-10 lg:flex xl:px-10">
          <BrandMark />
          <p className="mt-8 max-w-sm text-3xl leading-tight font-bold tracking-tight text-ink">
            Khôi phục truy cập, nhanh chóng và an toàn
          </p>
          <p className="mt-3 max-w-sm text-sm leading-6 text-muted">
            Đừng lo lắng. DealGo sẽ giúp bạn đặt lại mật khẩu quản trị thông qua
            email hoặc số điện thoại đã đăng ký.
          </p>
          <ul className="mt-8 space-y-5">
            {features.map((feature) => (
              <li key={feature.title} className="flex items-start gap-3">
                <span
                  className={`grid size-10 shrink-0 place-items-center rounded-xl ${feature.tone}`}
                >
                  <OpsIcon name={feature.icon} className="size-5" />
                </span>
                <span>
                  <span className="block text-sm font-semibold text-ink">
                    {feature.title}
                  </span>
                  <span className="mt-0.5 block text-sm leading-5 text-muted">
                    {feature.detail}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </div>
        <div className="px-5 py-8 sm:px-10 sm:py-10">
          <BrandMark />
          <h1 className="mt-6 text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quên mật khẩu
          </h1>
          <p className="mt-2 text-sm leading-6 text-muted">
            Nhập email hoặc số điện thoại để nhận hướng dẫn đặt lại mật khẩu.
          </p>
          <form
            onSubmit={onSubmit}
            className="mt-6 space-y-4"
            aria-busy={false}
          >
            <div className="space-y-1.5">
              <label
                htmlFor="forgot-account"
                className="text-sm font-medium text-ink"
              >
                Email hoặc số điện thoại
              </label>
              <div className="relative">
                <OpsIcon
                  name="user"
                  className="pointer-events-none absolute top-1/2 left-3 size-5 -translate-y-1/2 text-muted"
                />
                <input
                  id="forgot-account"
                  type="text"
                  inputMode="email"
                  autoComplete="username"
                  autoCapitalize="none"
                  spellCheck={false}
                  required
                  value={account}
                  onChange={(event) => {
                    setAccount(event.target.value);
                    setSent(false);
                  }}
                  placeholder="Nhập email hoặc số điện thoại..."
                  className={`h-12 w-full rounded-xl border border-border bg-white pr-3 pl-11 text-base text-ink placeholder:text-muted ${focusRing}`}
                />
              </div>
            </div>
            <div className="flex gap-3 rounded-2xl border border-delivery/20 bg-delivery/5 p-4">
              <span className="grid size-8 shrink-0 place-items-center rounded-full bg-delivery/15 text-delivery">
                <OpsIcon name="alert" className="size-4" />
              </span>
              <p className="text-sm leading-6 text-ink">
                Chúng tôi sẽ gửi liên kết đặt lại hoặc mã OTP tới tài khoản của
                bạn.
              </p>
            </div>
            <button
              type="submit"
              className={`inline-flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-brand text-sm font-semibold text-white ${focusRing}`}
            >
              Gửi yêu cầu
              <OpsIcon name="arrowRight" className="size-4" />
            </button>
            {sent ? (
              <p
                role="status"
                className="rounded-xl border border-success/30 bg-success/5 px-3 py-2 text-sm leading-6 text-ink"
              >
                Yêu cầu mẫu đã ghi nhận cho “{account.trim()}”. Bản demo không
                gửi email/OTP thật.
              </p>
            ) : null}
            {notice ? (
              <p role="alert" className="text-sm text-danger">
                {notice}
              </p>
            ) : null}
          </form>
          <div className="mt-6 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-border" />
            Hoặc
            <span className="h-px flex-1 bg-border" />
          </div>
          <Link
            href="/login"
            className={`mt-6 inline-flex h-12 w-full items-center justify-center rounded-xl border border-brand/40 bg-white text-sm font-semibold text-brand ${focusRing}`}
          >
            Quay lại đăng nhập
          </Link>
          <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              <span className="grid size-10 shrink-0 place-items-center rounded-full bg-canvas text-muted">
                <OpsIcon name="headset" className="size-5" />
              </span>
              <div className="min-w-0">
                <p className="text-sm font-medium text-ink">Cần hỗ trợ thêm?</p>
                <p className="text-sm text-muted">
                  Liên hệ đội ngũ kỹ thuật DealGo
                </p>
              </div>
            </div>
            <span
              aria-disabled="true"
              className="inline-flex h-10 items-center rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink"
            >
              Liên hệ hỗ trợ
            </span>
          </div>
        </div>
      </section>
    </main>
  );
}
