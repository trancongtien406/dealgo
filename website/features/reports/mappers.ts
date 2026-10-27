import type { NestOpsReport, ReportsSnapshotView } from "./types";

function dayLabel(day: string): string {
  const [, month, date] = day.split("-");
  return month && date ? `${date}/${month}` : day;
}

export function mapNestReport(data: NestOpsReport): ReportsSnapshotView {
  const daily = data.daily ?? [];
  const totals = data.totals;
  return {
    from: data.from,
    to: data.to,
    timezone: data.timezone,
    generatedAt: data.generatedAt,
    revenueVnd: totals.revenueVnd,
    rideRevenueVnd: totals.rideRevenueVnd,
    foodRevenueVnd: totals.foodRevenueVnd,
    commissionVnd: totals.commissionVnd,
    services: [
      { label: "Chuyến xe hoàn thành", value: totals.ridesCompleted, accent: "brand", icon: "car" },
      { label: "Đơn đồ ăn đã giao", value: totals.foodDelivered, accent: "food", icon: "utensils" },
      { label: "Chuyến xe đã huỷ", value: totals.ridesCancelled, accent: "delivery", icon: "gavel" },
      { label: "Đơn đồ ăn huỷ/thất bại", value: totals.foodCancelled, accent: "success", icon: "package" },
    ],
    trendDays: daily.map((row) => dayLabel(row.day)),
    trendSeries: [
      { label: "Chuyến xe hoàn thành", tone: "brand", values: daily.map((row) => row.ridesCompleted) },
      { label: "Đơn đồ ăn đã giao", tone: "food", values: daily.map((row) => row.foodDelivered) },
      {
        label: "Huỷ / thất bại",
        tone: "delivery",
        values: daily.map((row) => row.ridesCancelled + row.foodCancelled),
      },
    ],
  };
}
