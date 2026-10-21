import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

// DEC-PROD-036: Admin accounts have no self-service reset. A super-admin sets a new
// password from Nhân sự & phân quyền; that signs the account out everywhere and is audited.
const features = [
  {
    title: "Xác minh bởi quản trị viên",
    detail: "Chỉ super-admin mới đặt lại được mật khẩu, sau khi xác minh danh tính bạn",
    icon: "shield" as const,
    tone: "bg-brand/10 text-brand",
  },
  {
    title: "Đăng xuất mọi phiên",
    detail: "Khi đặt lại, mọi phiên Admin cũ của tài khoản bị thu hồi ngay",
    icon: "trend" as const,
    tone: "bg-success/10 text-success",
  },
  {
    title: "Có nhật ký kiểm toán",
    detail: "Mỗi lần đặt lại đều ghi người thực hiện và lý do",
    icon: "headset" as const,
    tone: "bg-brand/10 text-brand",
  },
] as const;

const steps = [
  "Liên hệ quản trị viên (super-admin) của đội vận hành DealGo qua kênh nội bộ.",
  "Cung cấp email đăng nhập Admin và xác minh danh tính theo yêu cầu.",
  "Quản trị viên đặt mật khẩu tạm thời tại Nhân sự & phân quyền và gửi riêng cho bạn.",
  "Đăng nhập lại bằng mật khẩu mới.",
] as const;

export default function ForgotPasswordPage() {
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
            Khôi phục truy cập qua quản trị viên
          </p>
          <p className="mt-3 max-w-sm text-sm leading-6 text-muted">
            Mật khẩu Admin chỉ được đặt lại bởi super-admin, có xác minh và ghi
            nhật ký.
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
            Vì lý do bảo mật, tài khoản Admin không tự đặt lại mật khẩu qua
            email hay OTP. Hãy liên hệ quản trị viên của bạn.
          </p>
          <ol
            data-testid="forgot-admin-steps"
            className="mt-6 space-y-3"
          >
            {steps.map((step, index) => (
              <li key={step} className="flex items-start gap-3">
                <span className="grid size-7 shrink-0 place-items-center rounded-full bg-brand/10 text-sm font-semibold text-brand">
                  {index + 1}
                </span>
                <span className="pt-0.5 text-sm leading-6 text-ink">{step}</span>
              </li>
            ))}
          </ol>
          <div className="mt-6 flex gap-3 rounded-2xl border border-delivery/20 bg-delivery/5 p-4">
            <span className="grid size-8 shrink-0 place-items-center rounded-full bg-delivery/15 text-delivery">
              <OpsIcon name="alert" className="size-4" />
            </span>
            <p className="text-sm leading-6 text-ink">
              DealGo không bao giờ hỏi mật khẩu của bạn. Đừng chia sẻ mật khẩu
              qua tin nhắn nhóm.
            </p>
          </div>
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
                  Liên hệ quản trị viên của bạn
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
