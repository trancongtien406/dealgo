import React from "react";
import { KpiCard } from "@/components/ui/admin-list-ui";
import { countFormat } from "@/lib/admin-format";
import type { ServiceActivity } from "../types";
import { formatShareRatio } from "../types";

interface ReportsKpiGridProps {
  activityTotal: number;
  services: readonly ServiceActivity[];
  isPending: boolean;
  isError: boolean;
}

export function ReportsKpiGrid({
  activityTotal,
  services,
  isPending,
  isError,
}: ReportsKpiGridProps) {
  return (
    <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
      <li className="h-full">
        <KpiCard
          label="Tổng hoạt động"
          value={
            isError
              ? "—"
              : isPending
                ? "Đang tải…"
                : countFormat.format(activityTotal)
          }
          note={isError ? "Mất kết nối máy chủ" : "Snapshot overview"}
          icon="chart"
          tone={isError ? "danger" : "brand"}
        />
      </li>
      {services.map((service) => (
        <li key={service.label} className="h-full">
          <KpiCard
            label={
              service.label === "Chuyến xe" ? "Tổng chuyến xe" : service.label
            }
            value={
              isError
                ? "—"
                : isPending
                  ? "Đang tải…"
                  : countFormat.format(service.value)
            }
            note={
              isError
                ? "Dữ liệu không khả dụng"
                : isPending
                  ? "Đang đồng bộ"
                  : `${formatShareRatio(service.value, activityTotal)} tổng hoạt động`
            }
            noteTone={isError ? undefined : service.accent}
            icon={service.icon}
            tone={isError ? "danger" : service.accent}
          />
        </li>
      ))}
    </ul>
  );
}
