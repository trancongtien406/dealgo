import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-canvas p-6 text-center text-ink">
      <div className="mb-6">
        <BrandMark />
      </div>

      <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-brand/10 text-brand ring-1 ring-brand/20">
        <OpsIcon name="search" className="size-7" />
      </div>

      <h1 className="mt-4 text-2xl font-bold tracking-tight text-ink">
        404 — Không tìm thấy trang
      </h1>

      <p className="mt-2 max-w-md text-sm text-muted">
        Đường dẫn bạn yêu cầu không tồn tại trên hệ thống quản trị hoặc đã được
        thay đổi cấu trúc.
      </p>

      <div className="mt-6 flex items-center gap-3">
        <Link
          href="/overview"
          className="inline-flex h-9 items-center gap-2 rounded-xl bg-brand px-4 text-xs font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors"
        >
          <OpsIcon name="overview" className="size-3.5" />
          Về Tổng quan Vận hành
        </Link>
      </div>
    </div>
  );
}
