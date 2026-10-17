"use client";

import { useMemo, useState } from "react";
import { useReportsQuery } from "@/features/reports/hooks";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  ExportCsvButton,
  PreviewButton,
} from "@/components/ui/admin-list-ui";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { isForbiddenError } from "@/lib/api/errors";
import type { Accent, ServiceActivity } from "@/features/reports/types";
import type { OverviewKpi } from "@/features/overview/types";
import { formatShareRatio } from "@/features/reports/types";
import { REPORTS_EXPORT_HEADERS } from "@/features/reports/constants";
import { ReportsKpiGrid } from "./reports-kpi-grid";
import { ReportsActivityChart } from "./reports-activity-chart";
import { ReportsServiceBreakdown } from "./reports-service-breakdown";

export function ReportsBoard() {
  const [selectedPreset, setSelectedPreset] = useState("today");
  const {
    data: overview,
    isPending,
    isError,
    error,
    refetch,
    isFetching,
  } = useReportsQuery({
    preset: selectedPreset,
  });
  const forbidden = isError && isForbiddenError(error);

  const services: readonly ServiceActivity[] = useMemo(() => {
    const kpis = overview?.kpis;
    const rideKpi = kpis?.find(
      (kpi: OverviewKpi) => kpi.label === "Chuyến xe",
    )?.value;
    const foodKpi = kpis?.find(
      (kpi: OverviewKpi) => kpi.label === "Đơn đồ ăn",
    )?.value;
    const deliveryKpi = kpis?.find(
      (kpi: OverviewKpi) => kpi.label === "Đang xử lý giao",
    )?.value;
    const negoKpi = kpis?.find(
      (kpi: OverviewKpi) => kpi.label === "Phiên trả giá",
    )?.value;

    const baseRide = rideKpi ?? overview?.areaTotal ?? 0;
    const baseFood = foodKpi ?? overview?.foodTotal ?? 0;
    const baseDelivery = deliveryKpi ?? overview?.pipelineTotal ?? 0;
    const baseNeg = negoKpi ?? 0;

    return [
      {
        label: "Chuyến xe",
        value: baseRide,
        accent: "brand" as Accent,
        icon: "car",
      },
      {
        label: "Đơn đồ ăn",
        value: baseFood,
        accent: "food" as Accent,
        icon: "utensils",
      },
      {
        label: "Đang xử lý giao",
        value: baseDelivery,
        accent: "delivery" as Accent,
        icon: "package",
      },
      {
        label: "Phiên trả giá",
        value: baseNeg,
        accent: "success" as Accent,
        icon: "gavel",
      },
    ];
  }, [overview]);

  const activityTotal = useMemo(() => {
    return services.reduce((sum, service) => sum + service.value, 0);
  }, [services]);

  const largestService = Math.max(
    0,
    ...services.map((service) => service.value),
  );

  const trendHours = overview?.trendHours ?? [];
  const trendSeries = overview?.trendSeries ?? [];

  const hasData = overview && activityTotal > 0;

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && hasData ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể kết nối máy chủ để cập nhật dữ liệu báo cáo."
          }
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Báo cáo", href: "/reports" },
          { label: "Thống kê & phân tích" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Tổng hợp dữ liệu vận hành
          </h1>
          <p className="mt-1 text-sm text-muted">
            Trích xuất dữ liệu tổng hợp trực tiếp từ Ops Overview Snapshot.
            Không đại diện cho hệ thống kế toán / báo cáo tài chính định kỳ.
          </p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
          <AdminHeaderDateFilter
            defaultPreset="today"
            labelPrefix="Kỳ báo cáo"
            onChange={(range) => {
              if (range.from && range.to) {
                setSelectedPreset(`${range.from}_${range.to}`);
              }
            }}
          />
          <PreviewButton onClick={() => void refetch()}>
            <OpsIcon
              name="refresh"
              className={`size-4 ${isFetching ? "animate-spin" : ""}`}
            />
            Làm mới
          </PreviewButton>
          <ExportCsvButton
            tone="brand"
            filename="reports-overview-snapshot.csv"
            headers={[...REPORTS_EXPORT_HEADERS]}
            rows={services.map((service) => [
              service.label,
              String(service.value),
              formatShareRatio(service.value, activityTotal),
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất báo cáo
          </ExportCsvButton>
        </div>
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập báo cáo vận hành"
          description="Tài khoản Ops hiện tại không được phân quyền xem tổng quan hoặc trích xuất báo cáo vận hành."
        />
      ) : isError && !hasData ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể kết nối máy chủ để tải dữ liệu báo cáo vận hành."
          }
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <div className="space-y-4">
          <ul
            className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5"
            aria-busy="true"
          >
            {Array.from({ length: 5 }, (_, index) => (
              <li
                key={index}
                className="min-h-[8.75rem] animate-pulse rounded-2xl border border-border bg-white p-4 shadow-sm"
              />
            ))}
          </ul>
          <div className="h-64 animate-pulse rounded-2xl border border-border bg-white p-4 shadow-sm" />
        </div>
      ) : (
        <>
          <ReportsKpiGrid
            activityTotal={activityTotal}
            services={services}
            isPending={isPending}
            isError={isError}
          />

          <ReportsActivityChart
            services={services}
            activityTotal={activityTotal}
            trendHours={trendHours}
            trendSeries={trendSeries}
            isError={isError}
            isPending={isPending}
          />

          <ReportsServiceBreakdown
            services={services}
            activityTotal={activityTotal}
            largestService={largestService}
            isPending={isPending}
            isError={isError}
          />
        </>
      )}
    </div>
  );
}
