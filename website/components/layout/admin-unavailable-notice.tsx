"use client";

import { OpsIcon } from "@/components/ui/ops-icons";

export function AdminUnavailableNotice({
  message,
}: {
  message?: string;
}) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-amber-500/10 text-amber-500 ring-1 ring-amber-500/20">
        <OpsIcon name="shield" className="size-7" />
      </div>

      <h2 className="mt-4 text-xl font-bold text-ink">
        Máy chủ vận hành DealGo tạm thời gián đoạn (502/503)
      </h2>

      <p className="mt-2 max-w-lg text-sm text-muted">
        {message ||
          "Không thể kết nối đến máy chủ backend (NestJS API cổng 3001). Vui lòng đảm bảo backend đang chạy (`npm run start:dev` trong thư mục backend). Phiên làm việc của bạn vẫn được bảo lưu an toàn."}
      </p>

      <div className="mt-6 flex items-center gap-3">
        <button
          type="button"
          onClick={() => {
            if (typeof window !== "undefined") {
              window.location.reload();
            }
          }}
          className="inline-flex h-9 items-center gap-2 rounded-xl bg-brand px-4 text-xs font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors cursor-pointer"
        >
          <OpsIcon name="refresh" className="size-3.5" />
          Tải lại trang
        </button>
      </div>
    </div>
  );
}
