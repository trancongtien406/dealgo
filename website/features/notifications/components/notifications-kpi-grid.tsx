import React from "react";
import { KpiCard } from "@/components/ui/admin-list-ui";
import { countFormat } from "@/lib/admin-format";
import type { NotificationCounts } from "@/features/notifications/api";

interface NotificationsKpiGridProps {
  counts: NotificationCounts;
  runningCount: number;
  pendingCount: number;
  publishedCmsCount: number;
  isPending: boolean;
  isError: boolean;
}

export function NotificationsKpiGrid({
  counts,
  runningCount,
  pendingCount,
  publishedCmsCount,
  isPending,
  isError,
}: NotificationsKpiGridProps) {
  return (
    <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
      <li className="h-full">
        <KpiCard
          label="Tổng chiến dịch"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(counts.all)
          }
          note={isError ? "Mất kết nối máy chủ" : "Trong toàn hệ thống"}
          icon="bell"
          tone={isError ? "danger" : "brand"}
        />
      </li>
      <li className="h-full">
        <KpiCard
          label="Đang chạy"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(runningCount)
          }
          note={isError ? "Dữ liệu không khả dụng" : "Push, In-app & tự động"}
          noteTone={isError ? undefined : "success"}
          icon="play"
          tone={isError ? "danger" : "success"}
        />
      </li>
      <li className="h-full">
        <KpiCard
          label="Chờ duyệt"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(pendingCount)
          }
          note={
            isError ? "Dữ liệu không khả dụng" : "Cần người phụ trách kiểm tra"
          }
          noteTone={isError ? undefined : "food"}
          icon="alert"
          tone={isError ? "danger" : "food"}
        />
      </li>
      <li className="h-full">
        <KpiCard
          label="Bài CMS đã đăng"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(publishedCmsCount)
          }
          note={
            isError
              ? "Dữ liệu không khả dụng"
              : "Hướng dẫn, tin tức, chính sách"
          }
          icon="receipt"
          tone={isError ? "danger" : "delivery"}
        />
      </li>
      <li className="h-full">
        <KpiCard
          label="Đã gửi"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(counts.sent)
          }
          note={isError ? "Dữ liệu không khả dụng" : "theo bộ đếm Nest"}
          icon="check"
          tone={isError ? "danger" : "brand"}
        />
      </li>
    </ul>
  );
}
