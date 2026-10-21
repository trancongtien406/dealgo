import type { OverviewSnapshot } from "@/features/overview/types";
import { countFormat } from "@/lib/admin-format";
import { catalogCategoryLabel } from "@/lib/category-labels";
import { mapOpsActivity, type NestOpsActivityItem } from "@/lib/ops-activity";
import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";

/** Nest GET /v1/ops/overview — OpsOverviewSummary + panels. */
export type NestOpsOverview = {
  ridesTotal: number;
  ridesNegotiating: number;
  ridesAssigned: number;
  ridesCompletedToday: number;
  ridesCancelledToday: number;
  foodOrdersTotal: number;
  foodPlaced: number;
  foodPreparing: number;
  /** In-flight food orders when Nest includes the field (PLACED…PICKED_UP). */
  foodInFlight?: number;
  foodDeliveredToday: number;
  customersTotal: number;
  driversTotal: number;
  driversOnline: number;
  storesTotal: number;
  exceptionsOpen: number;
  revenueVnd: null;
  commissionVnd: null;
  todayTimezone: string;
  generatedAt: string;
  hourlyTrend: {
    buckets: ReadonlyArray<{
      hour: string;
      rides: number;
      foodOrders: number;
      negotiating: number;
    }>;
  };
  recentActivity: readonly NestOpsActivityItem[];
  ridesByArea: ReadonlyArray<{ name: string; count: number; share: number }>;
  foodByCategory: ReadonlyArray<{ name: string; count: number; share: number }>;
};

export async function fetchOverview(): Promise<OverviewSnapshot> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestOpsOverview;
    }>(apiPaths.opsOverview());
    return mapNestOverview(envelope.data);
  } catch (error) {
    if (isUnavailable(error)) {
      throw new ApiError("Không tải được tổng quan vận hành từ máy chủ.", {
        code: "NOT_FOUND",
        status: 404,
      });
    }
    throw error;
  }
}

function mapNestOverview(data: NestOpsOverview): OverviewSnapshot {
  const buckets = data.hourlyTrend?.buckets ?? [];
  const areaRows = mergeShareRows(data.ridesByArea ?? []);
  const foodRows = mergeShareRows(
    (data.foodByCategory ?? []).map((row) => ({
      ...row,
      name: humanizeCategory(row.name),
    })),
  );
  const pipelineRows = buildPipelineRows(data);
  const processingFood =
    typeof data.foodInFlight === "number"
      ? data.foodInFlight
      : data.foodPlaced + data.foodPreparing;

  return {
    kpis: [
      {
        label: "Chuyến xe",
        value: data.ridesCompletedToday,
        note: `Tổng hệ thống: ${countFormat.format(data.ridesTotal)}`,
        icon: "car",
        tone: "brand",
      },
      {
        label: "Đơn đồ ăn",
        value: data.foodDeliveredToday,
        note: `Tổng đơn: ${countFormat.format(data.foodOrdersTotal)}`,
        icon: "utensils",
        tone: "food",
      },
      {
        label: "Đang xử lý giao",
        value: processingFood,
        note: `${data.foodPlaced} chờ · ${data.foodPreparing} chuẩn bị`,
        icon: "package",
        tone: "delivery",
      },
      {
        label: "Phiên trả giá",
        value: data.ridesNegotiating,
        note: `${data.ridesAssigned} đã gán tài xế`,
        icon: "gavel",
        tone: "success",
      },
    ],
    activity: mapOpsActivity(data.recentActivity ?? [], "relative"),
    trendHours: buckets.map((bucket) => formatHourLabel(bucket.hour)),
    trendSeries: [
      {
        label: "Chuyến xe",
        tone: "brand",
        values: buckets.map((bucket) => bucket.rides),
        total: data.ridesCompletedToday,
      },
      {
        label: "Đơn đồ ăn",
        tone: "food",
        values: buckets.map((bucket) => bucket.foodOrders),
        total: data.foodDeliveredToday,
      },
      {
        label: "Phiên trả giá",
        tone: "success",
        values: buckets.map((bucket) => bucket.negotiating),
        total: data.ridesNegotiating,
      },
    ],
    areaRows,
    foodRows,
    pipelineRows,
    areaTotal: sumCounts(areaRows),
    foodTotal: sumCounts(foodRows),
    pipelineTotal: sumCounts(pipelineRows),
    generatedAt: data.generatedAt,
    timezone: data.todayTimezone,
  };
}

function buildPipelineRows(data: NestOpsOverview) {
  const rows = [
    { name: "Chờ xác nhận", count: data.foodPlaced },
    { name: "Đang chuẩn bị", count: data.foodPreparing },
    { name: "Đã giao hôm nay", count: data.foodDeliveredToday },
  ].filter((row) => row.count > 0);
  return mergeShareRows(rows);
}

/** Collapse duplicate display names then recompute share so React keys stay unique. */
function mergeShareRows(
  rows: ReadonlyArray<{ name: string; count: number; share?: number }>,
): Array<{ name: string; count: number; share: number; id: string }> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const name = row.name.trim() || "Khác";
    map.set(name, (map.get(name) ?? 0) + row.count);
  }
  const merged = [...map.entries()]
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "vi"));
  const total = merged.reduce((sum, row) => sum + row.count, 0);
  return merged.map((row, index) => ({
    name: row.name,
    count: row.count,
    share: total > 0 ? Math.round((row.count / total) * 1000) / 10 : 0,
    id: `${row.name}::${index}`,
  }));
}

function humanizeCategory(raw: string): string {
  return catalogCategoryLabel(raw);
}

function formatHourLabel(hourKey: string): string {
  const match = hourKey.match(/(\d{2}):(\d{2})/);
  if (match) {
    return `${match[1]}:${match[2]}`;
  }
  return hourKey.slice(-5);
}

function sumCounts(rows: ReadonlyArray<{ count: number }>): number {
  return rows.reduce((sum, row) => sum + row.count, 0);
}

function isUnavailable(error: unknown): boolean {
  if (!(error instanceof ApiError)) {
    return false;
  }
  return (
    error.status === 404 || error.status === 501 || error.code === "NOT_FOUND"
  );
}
