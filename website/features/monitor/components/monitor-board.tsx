"use client";

import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useMonitorQuery } from "@/features/monitor/hooks";
import { OpsActivityFeed } from "@/components/ui/ops-activity-feed";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
  KpiCard,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { countFormat, type StatusTone } from "@/lib/admin-format";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { formatOpsStamp } from "@/lib/ops-time";
import {
  MONITOR_ICON_TEXT,
  MONITOR_ICON_TONE,
  MONITOR_PRIORITY_LABEL,
} from "@/features/monitor/constants";

const MonitorLiveMap = dynamic(
  () =>
    import("@/features/monitor/components/monitor-live-map").then(
      (mod) => mod.MonitorLiveMap,
    ),
  {
    ssr: false,
    loading: () => (
      <section className="min-h-104 animate-pulse rounded-2xl border border-border bg-white p-4 shadow-sm lg:col-span-3" />
    ),
  },
);

export function MonitorBoard() {
  const router = useRouter();
  const { data, isPending, isError, error, refetch, isFetching } =
    useMonitorQuery();
  const forbidden = isError && isForbiddenError(error);
  const unavailable =
    isError &&
    error instanceof ApiError &&
    (error.status === 404 || error.code === "NOT_FOUND");
  const demandMax = Math.max(
    1,
    ...(data?.areaDemand.map((row) => row.demand) ?? [1]),
  );

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Giám sát" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Giám sát vận hành trực tiếp
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi tài xế, chuyến xe và đơn hàng đang hoạt động theo thời gian
            thực.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={isPending || isFetching}
            onClick={() => {
              void refetch().then(() => {
                toast.success("Đã làm mới dữ liệu giám sát");
              });
            }}
            className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink shadow-xs transition-colors hover:border-brand/40 hover:bg-canvas ${focusRing}`}
          >
            <span className="relative flex size-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex size-2 rounded-full bg-emerald-500" />
            </span>
            <span>Trực tiếp · Làm mới</span>
            <OpsIcon
              name="refresh"
              className={`size-3.5 text-muted ${isFetching ? "animate-spin text-brand" : ""}`}
            />
          </button>
          <div className="inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink shadow-xs">
            <OpsIcon name="pin" className="size-4 text-brand" />
            <span>
              Khu vực:{" "}
              <strong className="font-semibold text-brand">
                {data?.regionLabel ?? "—"}
              </strong>
            </span>
          </div>
        </div>
      </div>

      {isError && !unavailable && !forbidden && data && data.kpis.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof ApiError && error.status === 401
              ? "Phiên đăng nhập đã hết hạn hoặc chưa đăng nhập. Vui lòng đăng nhập lại."
              : "Không tải được snapshot giám sát. Thử lại sau."
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
          title="Không có quyền truy cập giám sát trực tiếp"
          description="Tài khoản quản trị của bạn không có quyền xem bản đồ và luồng giám sát thời gian thực."
        />
      ) : isError && !unavailable && (!data || data.kpis.length === 0) ? (
        <AdminListErrorBanner
          message={
            error instanceof ApiError && error.status === 401
              ? "Phiên đăng nhập đã hết hạn hoặc chưa đăng nhập. Vui lòng đăng nhập lại."
              : "Không tải được snapshot giám sát. Thử lại sau."
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
        <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
          {Array.from({ length: 5 }, (_, index) => (
            <li
              key={index}
              className="min-h-[8.75rem] animate-pulse rounded-2xl border border-border bg-white p-4 shadow-sm"
            />
          ))}
        </ul>
      ) : unavailable ? (
        <AdminEmptyState
          icon="monitor"
          title="Chưa có dữ liệu giám sát trực tuyến"
          description="Hệ thống đang đồng bộ luồng vận hành. Vui lòng thử lại sau."
          action={
            <button
              type="button"
              className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink cursor-pointer ${focusRing}`}
              onClick={() => void refetch()}
            >
              Thử lại
            </button>
          }
        />
      ) : data && data.kpis.length === 0 ? (
        <AdminEmptyState
          icon="monitor"
          title="Snapshot trống"
          description="Máy chủ trả về monitor không có KPI."
        />
      ) : data ? (
        <>
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {data.kpis.map((kpi) => (
              <li key={kpi.label}>
                <KpiCard
                  label={kpi.label}
                  value={kpi.value}
                  trend={kpi.trend}
                  compare={kpi.compare}
                  note={kpi.note}
                  icon={kpi.icon}
                  tone={kpi.tone}
                />
              </li>
            ))}
          </ul>

          <div className="grid min-w-0 gap-4 lg:grid-cols-5">
            <MonitorLiveMap
              markers={data.mapMarkers}
              regionLabel={data.regionLabel}
            />
            <OpsActivityFeed
              className="lg:col-span-2"
              title="Hoạt động & cảnh báo gần đây"
              items={data.activity}
              viewAllHref="/exceptions"
            />
          </div>

          <div className="grid min-w-0 gap-4 lg:grid-cols-3">
            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <h2 className="text-base font-semibold text-ink">
                Nhu cầu theo khu vực
              </h2>
              <p className="mt-1 text-xs text-muted">
                Số yêu cầu theo khu vực đang hoạt động
              </p>
              {data.areaDemand.length === 0 ? (
                <p className="mt-4 text-sm text-muted">
                  Chưa có nhu cầu khu vực.
                </p>
              ) : (
                <div className="mt-3 min-w-0 overflow-x-auto">
                  <table className="w-full min-w-[280px] text-sm">
                    <thead className="sr-only">
                      <tr>
                        <th scope="col">Khu vực</th>
                        <th scope="col">Số yêu cầu</th>
                        <th scope="col">Mức tương đối</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.areaDemand.map((row, index) => (
                        <tr key={`${row.name}::${index}`}>
                          <th
                            scope="row"
                            className="max-w-[10rem] truncate py-2 pr-2 text-left font-medium text-ink"
                          >
                            {row.name}
                          </th>
                          <td className="px-2 py-2 text-right font-semibold text-ink tabular-nums">
                            {countFormat.format(row.demand)}
                          </td>
                          <td className="w-[40%] px-2 py-2">
                            <span className="block h-1.5 rounded-full bg-canvas">
                              <span
                                className="block h-1.5 rounded-full bg-brand"
                                style={{
                                  width: `${Math.round((row.demand / demandMax) * 100)}%`,
                                }}
                              />
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>

            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <h2 className="text-base font-semibold text-ink">
                Hàng chờ vận hành
              </h2>
              <p className="mt-1 text-xs text-muted">
                Yêu cầu chưa xử lý hoặc cần ghép nối
              </p>
              {data.queue.length === 0 ? (
                <p className="mt-4 text-sm text-muted">Hàng chờ trống.</p>
              ) : (
                <div className="mt-3 min-w-0 overflow-x-auto">
                  <table className="w-full min-w-[260px] text-sm">
                    <thead className="sr-only">
                      <tr>
                        <th scope="col">Loại</th>
                        <th scope="col">Số lượng</th>
                        <th scope="col">Ưu tiên</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.queue.map((row) => (
                        <tr key={row.key}>
                          <th
                            scope="row"
                            className="py-2.5 pr-2 text-left font-medium text-ink"
                          >
                            <span className="inline-flex items-center gap-2">
                              <OpsIcon
                                name={row.icon}
                                className={`size-4 ${MONITOR_ICON_TEXT[row.tone]}`}
                              />
                              {row.label}
                            </span>
                          </th>
                          <td className="px-2 py-2.5 text-right font-semibold text-ink tabular-nums">
                            {countFormat.format(row.count)}
                          </td>
                          <td className="py-2.5 pl-2 text-right">
                            <StatusChip tone={PRIORITY_TONE[row.priority]}>
                              {MONITOR_PRIORITY_LABEL[row.priority]}
                            </StatusChip>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>

            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <h2 className="text-base font-semibold text-ink">
                Cảnh báo hệ thống
              </h2>
              <p className="mt-1 text-xs text-muted">
                Các cảnh báo có thể cần can thiệp
              </p>
              {data.alerts.length === 0 ? (
                <p className="mt-4 text-sm text-muted">Không có cảnh báo.</p>
              ) : (
                <ul className="mt-3 space-y-3">
                  {data.alerts.map((item) => (
                    <li
                      key={item.code}
                      className="flex min-w-0 items-center gap-3"
                    >
                      <span
                        className={`grid size-8 shrink-0 place-items-center rounded-full ${MONITOR_ICON_TONE[item.tone]}`}
                      >
                        <OpsIcon name={item.icon} className="size-4" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium text-ink">
                          {item.title}
                        </p>
                        <p className="text-xs text-muted">{item.detail}</p>
                      </div>
                      <StatusChip tone={item.tone}>
                        {severityChip(item.severity)}
                      </StatusChip>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>

          {data.generatedAt ? (
            <p className="text-xs text-muted">
              Cập nhật {formatOpsStamp(data.generatedAt)}
            </p>
          ) : null}
        </>
      ) : null}
    </div>
  );
}

const PRIORITY_TONE: Record<"priority" | "high" | "normal", StatusTone> = {
  priority: "food",
  high: "food",
  normal: "success",
};

function severityChip(
  severity: "info" | "warning" | "danger" | "success",
): string {
  switch (severity) {
    case "danger":
      return "Nghiêm trọng";
    case "warning":
      return "Cần theo dõi";
    case "success":
      return "Ổn định";
    default:
      return "Thông tin";
  }
}
