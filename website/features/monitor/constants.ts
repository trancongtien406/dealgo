import type { StatusTone } from "@/lib/admin-format";

export const MONITOR_PRIORITY_LABEL: Record<
  "priority" | "high" | "normal",
  string
> = {
  priority: "Ưu tiên",
  high: "Cao",
  normal: "Bình thường",
};

export const MONITOR_ICON_TONE: Record<StatusTone, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

export const MONITOR_ICON_TEXT: Record<StatusTone, string> = {
  brand: "text-brand",
  food: "text-food",
  delivery: "text-delivery",
  success: "text-success",
  danger: "text-danger",
};
