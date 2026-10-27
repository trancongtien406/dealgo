import React from "react";
import { KpiCard } from "@/components/ui/admin-list-ui";
import { countFormat, vnd } from "@/lib/admin-format";
import type { ServiceActivity } from "../types";
import { formatShareRatio } from "../types";

interface ReportsKpiGridProps {
  /** Gross booking value in the period (completed rides + delivered food). */
  revenueVnd: number;
  rideRevenueVnd: number;
  foodRevenueVnd: number;
  /** Platform commission in the period (driver fees + merchant commission). */
  commissionVnd: number;
  activityTotal: number;
  services: readonly ServiceActivity[];
  isPending: boolean;
  isError: boolean;
}

export function ReportsKpiGrid({
  revenueVnd,
  rideRevenueVnd,
  foodRevenueVnd,
  commissionVnd,
  activityTotal,
  services,
  isPending,
  isError,
}: ReportsKpiGridProps) {
  return (
    <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <li className="h-full">
        <KpiCard
          label="Doanh thu (GMV)"
          value={isError ? "—" : isPending ? "Đang tải…" : vnd(revenueVnd)}
          note={
            isError
              ? "Mất kết nối máy chủ"
              : `Xe ${vnd(rideRevenueVnd)} · Đồ ăn ${vnd(foodRevenueVnd)}`
          }
          icon="chart"
          tone={isError ? "danger" : "brand"}
        />
      </li>
      <li className="h-full">
        <KpiCard
          label="Hoa hồng nền tảng"
          value={isError ? "—" : isPending ? "Đang tải…" : vnd(commissionVnd)}
          note={
            isError
              ? "Mất kết nối máy chủ"
              : `${countFormat.format(activityTotal)} chuyến/đơn kết thúc trong kỳ`
          }
          icon="chart"
          tone={isError ? "danger" : "success"}
        />
      </li>
      {services.map((service) => (
        <li key={service.label} className="h-full">
          <KpiCard
            label={service.label}
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
                  : `${formatShareRatio(service.value, activityTotal)} số chuyến/đơn kết thúc`
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
