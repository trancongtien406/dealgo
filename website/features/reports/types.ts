import type { OpsIconName } from "@/components/ui/ops-icons";
import type { OverviewSnapshot } from "@/features/overview/types";

export type Accent = "brand" | "food" | "delivery" | "success";

export interface ServiceActivity {
  label: string;
  value: number;
  accent: Accent;
  icon: OpsIconName;
}

export type ReportsSnapshotView = OverviewSnapshot;

export interface ReportsFilterParams {
  preset?: string;
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
