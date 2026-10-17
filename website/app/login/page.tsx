import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { LoginForm } from "./login-form";
import { LoginShowcase } from "./login-showcase";

export default function LoginPage() {
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
      <div
        aria-hidden="true"
        className="pointer-events-none absolute top-6 right-6 hidden h-36 w-36 sm:block [background-image:radial-gradient(circle,var(--color-border)_1.1px,transparent_1.1px)] [background-size:12px_12px] [mask-image:radial-gradient(circle_at_top_right,black,transparent_72%)]"
      />
      <section className="relative m-auto grid w-full max-w-6xl overflow-hidden rounded-[28px] border border-border bg-white shadow-[0_24px_70px_rgba(109,40,217,0.08)] lg:grid-cols-2">
        <LoginShowcase />
        <div className="px-5 py-8 sm:px-10 sm:py-10">
          <BrandMark />
          <h1 className="mt-6 text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Đăng nhập quản trị
          </h1>
          <p className="mt-2 text-sm leading-6 text-muted">
            Truy cập hệ thống quản trị DealGo
          </p>
          <LoginForm />
          <div className="mt-6 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-border" />
            Hoặc
            <span className="h-px flex-1 bg-border" />
          </div>
          <div className="mt-6 flex gap-3 rounded-2xl border border-border bg-canvas/70 p-4">
            <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-delivery/10 text-delivery">
              <OpsIcon name="shield" className="size-5" />
            </span>
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink">
                Truy cập an toàn, bảo mật đa lớp (MFA)
              </p>
              <p className="mt-1 text-sm leading-6 text-muted">
                Tài khoản quản trị được bảo vệ với xác thực hai yếu tố và giám
                sát đăng nhập liên tục.
              </p>
            </div>
          </div>
          <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              <span className="grid size-10 shrink-0 place-items-center rounded-full bg-canvas text-muted">
                <OpsIcon name="headset" className="size-5" />
              </span>
              <div className="min-w-0">
                <p className="text-sm font-medium text-ink">
                  Cần hỗ trợ đăng nhập?
                </p>
                <p className="text-sm text-muted">
                  Liên hệ đội ngũ kỹ thuật DealGo
                </p>
              </div>
            </div>
            <Link
              href="/support"
              className="inline-flex h-10 items-center rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink hover:bg-canvas transition-colors"
            >
              Trung tâm hỗ trợ
            </Link>
          </div>
          <div className="mt-8 flex flex-wrap items-center justify-between gap-3 border-t border-border pt-4 text-xs text-muted">
            <p>
              © {new Date().getFullYear()} DealGo Platform. Bảo lưu mọi quyền.
            </p>
            <div className="flex items-center gap-4">
              <Link href="/terms" className="hover:text-ink transition-colors">
                Điều khoản dịch vụ
              </Link>
              <span>·</span>
              <Link
                href="/privacy"
                className="hover:text-ink transition-colors"
              >
                Chính sách riêng tư
              </Link>
              <span>·</span>
              <Link
                href="/support"
                className="hover:text-ink transition-colors"
              >
                Trợ giúp
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
