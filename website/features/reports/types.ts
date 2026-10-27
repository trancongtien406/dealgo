import type { OpsIconName } from "@/components/ui/ops-icons";

export type Accent = "brand" | "food" | "delivery" | "success";

export interface ServiceActivity {
  label: string;
  value: number;
  accent: Accent;
  icon: OpsIconName;
}

/** Nest GET /v1/ops/reports — one Vietnam business day. */
export interface NestOpsReportDay {
  day: string;
  ridesCompleted: number;
  ridesCancelled: number;
  foodDelivered: number;
  foodCancelled: number;
  revenueVnd: number;
  commissionVnd: number;
}

export interface NestOpsReport {
  from: string;
  to: string;
  timezone: string;
  generatedAt: string;
  totals: Omit<NestOpsReportDay, "day"> & {
    rideRevenueVnd: number;
    foodRevenueVnd: number;
  };
  daily: NestOpsReportDay[];
}

export interface ReportsSnapshotView {
  from: string;
  to: string;
  timezone: string;
  generatedAt: string;
  revenueVnd: number;
  rideRevenueVnd: number;
  foodRevenueVnd: number;
  commissionVnd: number;
  services: ServiceActivity[];
  /** Day labels (dd/MM) for the trend chart. */
  trendDays: string[];
  trendSeries: { label: string; tone: Accent; values: number[] }[];
}

/** Inclusive Vietnam business-day range (YYYY-MM-DD). */
export interface ReportsFilterParams {
  from?: string | null;
  to?: string | null;
}

export const lineTone: Readonly<Record<Accent, string>> = {
  brand: "text-brand",
  food: "text-food",
  delivery: "text-delivery",
  success: "text-success",
};

export const barTone: Readonly<Record<Accent, string>> = {
  brand: "bg-brand",
  food: "bg-food",
  delivery: "bg-delivery",
  success: "bg-success",
};

export const strokeTone: Readonly<Record<Accent, string>> = {
  brand: "stroke-brand",
  food: "stroke-food",
  delivery: "stroke-delivery",
  success: "stroke-success",
};

export { shareFormat, formatShareRatio } from "@/lib/admin-format";
