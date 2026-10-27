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
import type { ServiceActivity } from "@/features/reports/types";
import { addDaysIso, todayIso } from "@/components/ui/date-picker";
import { formatShareRatio } from "@/features/reports/types";
import { REPORTS_EXPORT_HEADERS } from "@/features/reports/constants";
import { ReportsKpiGrid } from "./reports-kpi-grid";
import { ReportsActivityChart } from "./reports-activity-chart";
import { ReportsServiceBreakdown } from "./reports-service-breakdown";

const MAX_REPORT_DAYS = 92;

export function ReportsBoard() {
  const [range, setRange] = useState<{ from: string; to: string }>(() => {
    const today = todayIso();
    return { from: today, to: today };
  });
  const {
    data: report,
    isPending,
    isError,
    error,
    refetch,
    isFetching,
  } = useReportsQuery(range);
  const forbidden = isError && isForbiddenError(error);

  const services: readonly ServiceActivity[] = useMemo(
    () => report?.services ?? [],
    [report],
  );

  const activityTotal = useMemo(() => {
    return services.reduce((sum, service) => sum + service.value, 0);
  }, [services]);

  const largestService = Math.max(
    0,
    ...services.map((service) => service.value),
  );

  const trendDays = report?.trendDays ?? [];
  const trendSeries = report?.trendSeries ?? [];

  const hasData = Boolean(report);

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
            Số liệu theo ngày làm việc Việt Nam (Asia/Ho_Chi_Minh) cho kỳ đã chọn,
            tối đa {MAX_REPORT_DAYS} ngày. Không thay thế báo cáo tài chính kế toán.
          </p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
          <AdminHeaderDateFilter
            defaultPreset="today"
            labelPrefix="Kỳ báo cáo"
            onChange={(next) => {
              const today = todayIso();
              if (next.from || next.to) {
                const from = next.from ?? next.to ?? today;
                const to = next.to ?? from;
                // The report covers at most MAX_REPORT_DAYS; clamp longer picks to the latest days.
                const earliest = addDaysIso(to, -(MAX_REPORT_DAYS - 1));
                setRange({ from: from < earliest ? earliest : from, to });
              } else {
                // "Tất cả thời gian": the latest MAX_REPORT_DAYS days.
                setRange({ from: addDaysIso(today, -(MAX_REPORT_DAYS - 1)), to: today });
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
            filename={`reports-${range.from}_${range.to}.csv`}
            headers={[...REPORTS_EXPORT_HEADERS]}
            rows={[
              ...services.map((service) => [
                service.label,
                String(service.value),
                formatShareRatio(service.value, activityTotal),
              ]),
              ["Doanh thu (GMV, VND)", String(report?.revenueVnd ?? 0), ""],
              ["Hoa hồng nền tảng (VND)", String(report?.commissionVnd ?? 0), ""],
            ]}
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
            revenueVnd={report?.revenueVnd ?? 0}
            rideRevenueVnd={report?.rideRevenueVnd ?? 0}
            foodRevenueVnd={report?.foodRevenueVnd ?? 0}
            commissionVnd={report?.commissionVnd ?? 0}
            activityTotal={activityTotal}
            services={services}
            isPending={isPending}
            isError={isError}
          />

          <ReportsActivityChart
            services={services}
            activityTotal={activityTotal}
            trendDays={trendDays}
            trendSeries={trendSeries}
            isError={isError}
            isPending={isPending}
          />

          <ReportsServiceBreakdown
            services={services}
            activityTotal={activityTotal}
            largestService={largestService}
            range={range}
            isPending={isPending}
            isError={isError}
          />
        </>
      )}
    </div>
  );
}
