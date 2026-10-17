"use client";

import { useEffect } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";

export default function AdminError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log unexpected admin segment failures
    console.error("[OpsSegmentError]", error);
  }, [error]);

  const isUnavailable =
    error.message?.includes("502") ||
    error.message?.includes("503") ||
    error.message?.toLowerCase().includes("không khả dụng") ||
    error.message?.toLowerCase().includes("kết nối");

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-amber-500/10 text-amber-500 ring-1 ring-amber-500/20">
        <OpsIcon name="shield" className="size-7" />
      </div>

      <h2 className="mt-4 text-xl font-bold text-ink">
        {isUnavailable
          ? "Máy chủ vận hành DealGo tạm thời gián đoạn"
          : "Đã xảy ra lỗi trong phân hệ vận hành"}
      </h2>

      <p className="mt-2 max-w-md text-sm text-muted">
        {isUnavailable
          ? "Kết nối tới NestJS API backend bị timeout hoặc gián đoạn. Phiên đăng nhập của bạn được bảo lưu an toàn."
          : error.message ||
            "Hệ thống gặp sự cố không mong muốn khi tải dữ liệu trang."}
      </p>

      <div className="mt-6 flex items-center gap-3">
        <button
          type="button"
          onClick={() => reset()}
          className="inline-flex h-9 items-center gap-2 rounded-xl bg-brand px-4 text-xs font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors cursor-pointer"
        >
          <OpsIcon name="refresh" className="size-3.5" />
          Thử tải lại phân hệ
        </button>

        <button
          type="button"
          onClick={() => {
            if (typeof window !== "undefined") {
              window.location.reload();
            }
          }}
          className="inline-flex h-9 items-center gap-2 rounded-xl border border-border bg-surface px-4 text-xs font-medium text-ink hover:bg-canvas transition-colors cursor-pointer"
        >
          Tải lại toàn trang
        </button>
      </div>
    </div>
  );
}
