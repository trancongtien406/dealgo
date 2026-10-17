import type { OpsIconName } from "@/components/ui/ops-icons";
import type { OpsActivityItem } from "@/components/ui/ops-activity-feed";
import type { MapMarker } from "@/components/ui/real-map-view";
import type { StatusTone } from "@/lib/admin-format";

export type MonitorKpi = {
  label: string;
  value: number;
  trend?: number;
  compare?: string;
  note?: string;
  icon: OpsIconName;
  tone: StatusTone;
};

export type MonitorQueueItem = {
  key: string;
  label: string;
  count: number;
  priority: "priority" | "high" | "normal";
  icon: OpsIconName;
  tone: StatusTone;
};

export type MonitorAreaDemand = {
  name: string;
  demand: number;
};

export type MonitorAlert = {
  code: string;
  title: string;
  detail: string;
  severity: "info" | "warning" | "danger" | "success";
  tone: StatusTone;
  icon: OpsIconName;
};

export type MonitorSnapshot = {
  kpis: readonly MonitorKpi[];
  mapMarkers: readonly MapMarker[];
  queue: readonly MonitorQueueItem[];
  areaDemand: readonly MonitorAreaDemand[];
  activity: readonly OpsActivityItem[];
  alerts: readonly MonitorAlert[];
  generatedAt: string | null;
  regionLabel: string;
};
