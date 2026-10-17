"use client";

import { useEffect } from "react";
import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";

export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[RootError]", error);
  }, [error]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-canvas p-6 text-center text-ink">
      <div className="mb-6">
        <BrandMark />
      </div>

      <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-danger/10 text-danger ring-1 ring-danger/20">
        <OpsIcon name="alert" className="size-7" />
      </div>

      <h1 className="mt-4 text-2xl font-bold tracking-tight text-ink">
        Đã xảy ra sự cố không mong muốn
      </h1>

      <p className="mt-2 max-w-md text-sm text-muted">
        Hệ thống giao diện DealGo gặp lỗi kết nối hoặc xử lý dữ liệu. Phiên làm
        việc của bạn vẫn an toàn.
      </p>

      <div className="mt-6 flex items-center gap-3">
        <button
          type="button"
          onClick={() => reset()}
          className="inline-flex h-9 items-center gap-2 rounded-xl bg-brand px-4 text-xs font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors cursor-pointer"
        >
          <OpsIcon name="refresh" className="size-3.5" />
          Thử lại
        </button>

        <Link
          href="/overview"
          className="inline-flex h-9 items-center gap-2 rounded-xl border border-border bg-surface px-4 text-xs font-medium text-ink hover:bg-canvas transition-colors"
        >
          Trang chủ vận hành
        </Link>
      </div>
    </div>
  );
}
