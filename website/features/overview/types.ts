import type { OpsIconName } from "@/components/ui/ops-icons";
import type { OpsActivityItem } from "@/components/ui/ops-activity-feed";
import type { OpsBreakdownRow } from "@/components/ui/ops-breakdown-table";
import type { OpsTrendSeries } from "@/components/ui/ops-service-trend-chart";
import type { StatusTone } from "@/lib/admin-format";

export type OverviewKpi = {
  label: string;
  value: number;
  trend?: number;
  compare?: string;
  note?: string;
  noteTone?: StatusTone;
  icon: OpsIconName;
  tone: StatusTone;
};

export type OverviewSnapshot = {
  kpis: readonly OverviewKpi[];
  activity: readonly OpsActivityItem[];
  trendHours: readonly string[];
  trendSeries: readonly OpsTrendSeries[];
  areaRows: readonly OpsBreakdownRow[];
  foodRows: readonly OpsBreakdownRow[];
  pipelineRows: readonly OpsBreakdownRow[];
  areaTotal: number;
  foodTotal: number;
  pipelineTotal: number;
  /** Today's gross booking value (VND); null when the backend could not compute it. */
  revenueVnd: number | null;
  /** Today's platform commission (VND); null when unavailable. */
  commissionVnd: number | null;
  generatedAt: string | null;
  timezone: string;
};
