import type { MonitorSnapshot } from "@/features/monitor/types";
import type { MapMarker } from "@/components/ui/real-map-view";
import type { OpsIconName } from "@/components/ui/ops-icons";
import { mapOpsActivity, type NestOpsActivityItem } from "@/lib/ops-activity";
import type { StatusTone } from "@/lib/admin-format";
import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";

/** Nest GET /v1/ops/monitor/snapshot — OpsMonitorSnapshot + panels. */
export type NestOpsMonitorSnapshot = {
  ridesOpen: number;
  ridesNegotiating: number;
  foodReady: number;
  foodInFlight: number;
  driversOnline: number;
  exceptionsOpen: number;
  generatedAt: string;
  mapMarkers: ReadonlyArray<{
    id: string;
    kind: "driver" | "ride" | "food";
    lat: number;
    lng: number;
    label: string;
  }>;
  queue: ReadonlyArray<{
    key: string;
    label: string;
    count: number;
    priority: "priority" | "high" | "normal";
  }>;
  areaDemand: ReadonlyArray<{ name: string; demand: number }>;
  recentActivity: readonly NestOpsActivityItem[];
  systemAlerts: ReadonlyArray<{
    code: string;
    title: string;
    detail: string;
    severity: "info" | "warning" | "danger" | "success";
  }>;
  pilotZoneLabel?: string;
};

const QUEUE_META: Record<string, { icon: OpsIconName; tone: StatusTone }> = {
  negotiating: { icon: "gavel", tone: "food" },
  food_ready: { icon: "utensils", tone: "food" },
  food_in_flight: { icon: "package", tone: "delivery" },
  exceptions: { icon: "alert", tone: "danger" },
};

const PRIORITY_TONE: Record<"priority" | "high" | "normal", StatusTone> = {
  priority: "food",
  high: "food",
  normal: "success",
};

const ALERT_META: Record<string, { icon: OpsIconName; tone: StatusTone }> = {
  exceptions_open: { icon: "alert", tone: "danger" },
  food_ready_high: { icon: "utensils", tone: "food" },
  rides_negotiating_high: { icon: "gavel", tone: "food" },
  drivers_online_zero: { icon: "driver", tone: "danger" },
};

export async function fetchMonitorSnapshot(): Promise<MonitorSnapshot> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestOpsMonitorSnapshot;
    }>(apiPaths.opsMonitor());
    return mapNestMonitor(envelope.data);
  } catch (error) {
    if (isUnavailable(error)) {
      throw new ApiError("Không tải được snapshot giám sát từ máy chủ.", {
        code: "NOT_FOUND",
        status: 404,
      });
    }
    throw error;
  }
}

function mapNestMonitor(data: NestOpsMonitorSnapshot): MonitorSnapshot {
  return {
    kpis: [
      {
        label: "Chuyến xe đang chạy",
        value: data.ridesOpen,
        icon: "car",
        tone: "brand",
        note: "trạng thái mở",
      },
      {
        label: "Tài xế đang online",
        value: data.driversOnline,
        icon: "users",
        tone: "success",
        note: "presence",
      },
      {
        label: "Phiên trả giá đang mở",
        value: data.ridesNegotiating,
        icon: "gavel",
        tone: "food",
        note: "NEGOTIATING",
      },
      {
        label: "Đơn đồ ăn đang xử lý",
        value: data.foodReady,
        icon: "utensils",
        tone: "delivery",
        note: "READY",
      },
      {
        label: "Đơn đang giao",
        value: data.foodInFlight,
        icon: "package",
        tone: "success",
        note: "in-flight",
      },
    ],
    mapMarkers: (data.mapMarkers ?? []).map(mapMarker),
    queue: (data.queue ?? []).map((item) => {
      const meta = QUEUE_META[item.key] ?? {
        icon: "alert" as OpsIconName,
        tone: PRIORITY_TONE[item.priority],
      };
      return {
        key: item.key,
        label: item.label,
        count: item.count,
        priority: item.priority,
        icon: meta.icon,
        tone: meta.tone,
      };
    }),
    areaDemand: mergeAreaDemandRows(data.areaDemand ?? []),
    activity: mapOpsActivity(data.recentActivity ?? [], "clock"),
    alerts: (data.systemAlerts ?? []).map((alert) => {
      const meta = ALERT_META[alert.code] ?? severityMeta(alert.severity);
      return {
        code: alert.code,
        title: alert.title,
        detail: alert.detail,
        severity: alert.severity,
        tone: meta.tone,
        icon: meta.icon,
      };
    }),
    generatedAt: data.generatedAt,
    regionLabel: data.pilotZoneLabel?.trim() || "Toàn hệ thống",
  };
}

/** Defensive merge if Nest ever returns duplicate area display names. */
function mergeAreaDemandRows(
  rows: ReadonlyArray<{ name: string; demand: number }>,
): Array<{ name: string; demand: number }> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const name = row.name.trim() || "Khác";
    map.set(name, (map.get(name) ?? 0) + row.demand);
  }
  return [...map.entries()]
    .map(([name, demand]) => ({ name, demand }))
    .sort((a, b) => b.demand - a.demand || a.name.localeCompare(b.name, "vi"));
}

function mapMarker(
  marker: NestOpsMonitorSnapshot["mapMarkers"][number],
): MapMarker {
  const type =
    marker.kind === "driver"
      ? "driver"
      : marker.kind === "food"
        ? "store"
        : "pickup";
  return {
    id: marker.id,
    lat: marker.lat,
    lng: marker.lng,
    label: marker.label,
    type,
  };
}

function severityMeta(
  severity: NestOpsMonitorSnapshot["systemAlerts"][number]["severity"],
) {
  switch (severity) {
    case "danger":
      return { icon: "alert" as OpsIconName, tone: "danger" as StatusTone };
    case "warning":
      return { icon: "alert" as OpsIconName, tone: "food" as StatusTone };
    case "success":
      return { icon: "check" as OpsIconName, tone: "success" as StatusTone };
    default:
      return { icon: "shield" as OpsIconName, tone: "brand" as StatusTone };
  }
}

function isUnavailable(error: unknown): boolean {
  if (!(error instanceof ApiError)) {
    return false;
  }
  return (
    error.status === 404 || error.status === 501 || error.code === "NOT_FOUND"
  );
}
