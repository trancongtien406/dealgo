"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useOverviewQuery } from "@/features/overview/hooks";
import { OpsActivityFeed } from "@/components/ui/ops-activity-feed";
import { OpsBreakdownTable } from "@/components/ui/ops-breakdown-table";
import { AdminBreadcrumb, KpiCard } from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { formatOpsStamp } from "@/lib/ops-time";
import { vnd } from "@/lib/admin-format";

const OpsServiceTrendChart = dynamic(
  () =>
    import("@/components/ui/ops-service-trend-chart").then(
      (mod) => mod.OpsServiceTrendChart,
    ),
  {
    ssr: false,
    loading: () => (
      <div
        className="mt-4 h-54 animate-pulse rounded-xl border border-dashed border-border bg-canvas/60"
        aria-hidden="true"
      />
    ),
  },
);

export function OverviewDashboard() {
  const router = useRouter();
  const { data, isPending, isError, error, refetch } = useOverviewQuery();
  const forbidden = isError && isForbiddenError(error);
  const unavailable =
    isError &&
    error instanceof ApiError &&
    (error.status === 404 || error.code === "NOT_FOUND");

  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tổng quan" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Tổng quan vận hành
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi sản lượng chuyến đi, đơn đồ ăn và phiên trả giá toàn sàn.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="inline-flex h-9 items-center rounded-lg border border-border bg-white px-3 text-sm text-ink">
            Hôm nay · giờ Việt Nam
          </p>
          <Link
            href="/reports"
            className="inline-flex h-9 items-center rounded-lg px-3 text-sm font-medium text-brand hover:underline"
          >
            Báo cáo theo kỳ
          </Link>
        </div>
      </div>

      {isError && !unavailable && !forbidden && data && data.kpis.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof ApiError && error.status === 401
              ? "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
              : "Không tải được tổng quan. Thử lại sau."
          }
          onRetry={() => {
            if (error instanceof ApiError && error.status === 401) {
              router.push("/login");
            } else {
              void refetch();
            }
          }}
        />
      ) : null}

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập tổng quan vận hành"
          description="Tài khoản quản trị của bạn không có quyền xem bảng số liệu tổng quan toàn sàn."
        />
      ) : isError && !unavailable && (!data || data.kpis.length === 0) ? (
        <AdminListErrorBanner
          message={
            error instanceof ApiError && error.status === 401
              ? "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
              : "Không tải được tổng quan. Thử lại sau."
          }
          onRetry={() => {
            if (error instanceof ApiError && error.status === 401) {
              router.push("/login");
            } else {
              void refetch();
            }
          }}
        />
      ) : isPending ? (
        <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }, (_, index) => (
            <li
              key={index}
              className="min-h-[8.75rem] animate-pulse rounded-2xl border border-border bg-white p-4 shadow-sm"
            />
          ))}
        </ul>
      ) : unavailable ? (
        <AdminEmptyState
          icon="chart"
          title="Chưa có dữ liệu tổng quan"
          description="Hệ thống đang đồng bộ thống kê từ máy chủ. Vui lòng thử lại sau."
          action={
            <button
              type="button"
              className="inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink cursor-pointer"
              onClick={() => void refetch()}
            >
              Thử lại
            </button>
          }
        />
      ) : data && data.kpis.length === 0 ? (
        <AdminEmptyState
          icon="chart"
          title="Tổng quan trống"
          description="Không có dữ liệu thống kê trong khoảng thời gian đã chọn."
        />
      ) : data ? (
        <>
          <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {data.kpis.map((kpi) => (
              <li key={kpi.label}>
                <KpiCard
                  label={kpi.label}
                  value={kpi.value}
                  trend={kpi.trend}
                  compare={kpi.compare}
                  note={kpi.note}
                  noteTone={kpi.noteTone}
                  icon={kpi.icon}
                  tone={kpi.tone}
                />
              </li>
            ))}
          </ul>
          <p className="text-sm text-muted">
            Doanh thu hôm nay (GMV):{" "}
            <span className="font-semibold text-ink tabular-nums">
              {vnd(data.revenueVnd)}
            </span>{" "}
            · Hoa hồng nền tảng:{" "}
            <span className="font-semibold text-ink tabular-nums">
              {vnd(data.commissionVnd)}
            </span>
          </p>

          <div className="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.7fr)_minmax(18rem,1fr)]">
            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <h2 className="text-base font-semibold text-ink">
                    Xu hướng dịch vụ
                  </h2>
                  <p className="mt-1 text-sm text-muted">
                    Sản lượng theo giờ từ dữ liệu vận hành
                  </p>
                </div>
                <p className="inline-flex h-9 shrink-0 items-center rounded-lg border border-border bg-canvas/50 px-3 text-sm text-ink">
                  24 giờ qua
                </p>
              </div>
              <div className="mt-4">
                <OpsServiceTrendChart
                  hours={data.trendHours}
                  series={data.trendSeries}
                  emptyMessage="Máy chủ chưa trả chuỗi xu hướng theo giờ trong khoảng thời gian này."
                />
              </div>
            </section>
            <OpsActivityFeed
              title="Hoạt động gần đây"
              items={data.activity}
              viewAllHref="/exceptions"
            />
          </div>

          <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
            <OpsBreakdownTable
              title="Chuyến xe theo khu vực"
              nameHeader="Khu vực"
              countHeader="Số chuyến"
              icon="car"
              tone="brand"
              rows={data.areaRows}
              total={data.areaTotal}
              viewAllHref="/rides"
            />
            <OpsBreakdownTable
              title="Đơn đồ ăn theo danh mục"
              nameHeader="Danh mục"
              countHeader="Số đơn"
              icon="utensils"
              tone="food"
              rows={data.foodRows}
              total={data.foodTotal}
              viewAllHref="/food-orders"
            />
            <OpsBreakdownTable
              title="Đơn đồ ăn theo trạng thái"
              nameHeader="Trạng thái"
              countHeader="Số đơn"
              icon="package"
              tone="delivery"
              rows={data.pipelineRows}
              total={data.pipelineTotal}
              viewAllHref="/food-orders"
            />
          </div>

          {data.generatedAt ? (
            <p className="text-xs text-muted">
              Cập nhật {formatOpsStamp(data.generatedAt)}
              {data.timezone ? ` · ${data.timezone}` : null}
            </p>
          ) : null}
        </>
      ) : null}
    </div>
  );
}
