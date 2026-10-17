import { OPS_KPI_TODAY_UTC_OFFSET_HOURS } from './ops-overview.constants.js';

export type OpsHourlyTrendBucket = {
  hour: string;
  rides: number;
  foodOrders: number;
  negotiating: number;
};

export type OpsRecentActivityItem = {
  kind: 'ride' | 'food' | 'exception';
  title: string;
  detail: string;
  at: string;
  tone?: string;
};

export type OpsShareRow = {
  name: string;
  count: number;
  share: number;
};

export type OpsMapMarker = {
  id: string;
  kind: 'driver' | 'ride' | 'food';
  lat: number;
  lng: number;
  label: string;
};

export type OpsQueueItem = {
  key: string;
  label: string;
  count: number;
  priority: 'priority' | 'high' | 'normal';
};

export type OpsAreaDemandRow = {
  name: string;
  demand: number;
};

export type OpsSystemAlert = {
  code: string;
  title: string;
  detail: string;
  severity: 'info' | 'warning' | 'danger' | 'success';
};

export type OpsOverviewPanels = {
  hourlyTrend: { buckets: OpsHourlyTrendBucket[] };
  recentActivity: OpsRecentActivityItem[];
  ridesByArea: OpsShareRow[];
  foodByCategory: OpsShareRow[];
};

export type OpsMonitorPanels = {
  mapMarkers: OpsMapMarker[];
  queue: OpsQueueItem[];
  areaDemand: OpsAreaDemandRow[];
  recentActivity: OpsRecentActivityItem[];
  systemAlerts: OpsSystemAlert[];
  pilotZoneLabel?: string;
};

export const EMPTY_OVERVIEW_PANELS: OpsOverviewPanels = {
  hourlyTrend: { buckets: [] },
  recentActivity: [],
  ridesByArea: [],
  foodByCategory: [],
};

export const EMPTY_MONITOR_PANELS: OpsMonitorPanels = {
  mapMarkers: [],
  queue: [],
  areaDemand: [],
  recentActivity: [],
  systemAlerts: [],
};

/** First comma segment, trimmed; empty → Khác. Caps length for map/list labels. */
export function normalizeShortAreaLabel(raw: string | null | undefined): string {
  const trimmed = (raw ?? '').trim();
  if (!trimmed) {
    return 'Khác';
  }
  // Scale/perf seed labels are not operator-facing place names.
  if (/^perf\b/i.test(trimmed)) {
    return 'Khu vực thử nghiệm';
  }
  const head = trimmed.split(',')[0]?.trim() || trimmed;
  if (head.length <= 48) {
    return head;
  }
  return `${head.slice(0, 47)}…`;
}

/**
 * Merge rows that share the same display name (e.g. many Perf pickup*
 * labels collapsing to "Khu vực thử nghiệm") before computing shares.
 */
export function mergeCountRowsByName(
  rows: ReadonlyArray<{ name: string; count: number }>,
): Array<{ name: string; count: number }> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const name = row.name.trim() || 'Khác';
    map.set(name, (map.get(name) ?? 0) + row.count);
  }
  return [...map.entries()]
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, 'vi'));
}

export function withShare(
  rows: ReadonlyArray<{ name: string; count: number }>,
): OpsShareRow[] {
  const merged = mergeCountRowsByName(rows);
  const total = merged.reduce((sum, row) => sum + row.count, 0);
  if (total <= 0) {
    return merged.map((row) => ({ name: row.name, count: row.count, share: 0 }));
  }
  return merged.map((row) => ({
    name: row.name,
    count: row.count,
    share: Math.round((row.count / total) * 1000) / 10,
  }));
}

export type HourlyCountRow = { hourKey: string; cnt: bigint | number };

/**
 * Build 24 consecutive local (Asia/Ho_Chi_Minh) hour buckets ending at the
 * current local hour. Missing SQL hours become zeros.
 */
export function buildHourlyTrendBuckets(
  now: Date,
  rides: HourlyCountRow[],
  foodOrders: HourlyCountRow[],
  negotiating: HourlyCountRow[],
): OpsHourlyTrendBucket[] {
  const rideMap = toHourCountMap(rides);
  const foodMap = toHourCountMap(foodOrders);
  const negoMap = toHourCountMap(negotiating);
  const keys = last24LocalHourKeys(now);
  return keys.map((hour) => ({
    hour,
    rides: rideMap.get(hour) ?? 0,
    foodOrders: foodMap.get(hour) ?? 0,
    negotiating: negoMap.get(hour) ?? 0,
  }));
}

export function mergeRecentActivityItems(
  items: ReadonlyArray<OpsRecentActivityItem>,
  limit: number,
): OpsRecentActivityItem[] {
  return [...items]
    .sort((a, b) => {
      const byTime = Date.parse(b.at) - Date.parse(a.at);
      if (byTime !== 0) {
        return byTime;
      }
      return `${a.kind}:${a.title}`.localeCompare(`${b.kind}:${b.title}`);
    })
    .slice(0, Math.max(0, limit));
}

const RIDE_STATUS_LABEL: Record<string, string> = {
  NEGOTIATING: 'Đang thương lượng',
  ASSIGNED: 'Đã gán tài xế',
  DRIVER_EN_ROUTE: 'Tài xế đang đến',
  DRIVER_ARRIVED: 'Tài xế đã tới',
  IN_TRIP: 'Đang chạy',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Đã hủy',
  EXPIRED: 'Hết hạn',
};

const FOOD_STATUS_LABEL: Record<string, string> = {
  PLACED: 'Chờ xác nhận',
  CONFIRMED: 'Đã xác nhận',
  PREPARING: 'Đang chuẩn bị',
  READY: 'Sẵn sàng lấy',
  ASSIGNED: 'Đã gán tài xế',
  PICKED_UP: 'Đang giao',
  DELIVERED: 'Đã giao',
  CANCELLED: 'Đã hủy',
  FAILED: 'Thất bại',
};

const EXCEPTION_REASON_LABEL: Record<string, string> = {
  terminal: 'vừa kết thúc bất thường',
  stuck: 'bị kẹt quá lâu',
};

function statusLabel(kind: 'ride' | 'food', status: string): string {
  const map = kind === 'ride' ? RIDE_STATUS_LABEL : FOOD_STATUS_LABEL;
  return map[status] ?? status;
}

export function activityFromRideRow(row: {
  id: string;
  status: string;
  pickupLabel: string | null;
  updatedAt: Date | string;
}): OpsRecentActivityItem {
  const area = normalizeShortAreaLabel(row.pickupLabel);
  return {
    kind: 'ride',
    title: area !== 'Khác' ? `Chuyến xe · ${area}` : 'Chuyến xe mới cập nhật',
    detail: `${statusLabel('ride', row.status)} · mã ${shortId(row.id)}`,
    at: toIso(row.updatedAt),
    tone: row.status === 'NEGOTIATING' ? 'brand' : 'info',
  };
}

export function activityFromFoodRow(row: {
  id: string;
  status: string;
  dropoffLabel: string | null;
  updatedAt: Date | string;
}): OpsRecentActivityItem {
  const area = normalizeShortAreaLabel(row.dropoffLabel);
  return {
    kind: 'food',
    title: area !== 'Khác' ? `Đơn đồ ăn · ${area}` : 'Đơn đồ ăn mới cập nhật',
    detail: `${statusLabel('food', row.status)} · mã ${shortId(row.id)}`,
    at: toIso(row.updatedAt),
    tone: 'food',
  };
}

export function activityFromExceptionRow(row: {
  kind: 'ride' | 'food';
  id: string;
  status: string;
  reason: string;
  updatedAt: string;
  label?: string | null;
}): OpsRecentActivityItem {
  const area = normalizeShortAreaLabel(row.label);
  const kindLabel = row.kind === 'ride' ? 'chuyến xe' : 'đơn đồ ăn';
  const reasonLabel =
    EXCEPTION_REASON_LABEL[row.reason] ?? row.reason;
  return {
    kind: 'exception',
    title:
      area !== 'Khác'
        ? `Ngoại lệ ${kindLabel} · ${area}`
        : `Ngoại lệ ${kindLabel}`,
    detail: `${statusLabel(row.kind, row.status)} · ${reasonLabel}`,
    at: row.updatedAt,
    tone: 'danger',
  };
}

export function buildMonitorQueue(input: {
  ridesNegotiating: number;
  foodReady: number;
  foodInFlight: number;
  exceptionsOpen: number;
}): OpsQueueItem[] {
  return [
    {
      key: 'negotiating',
      label: 'Đang thương lượng',
      count: input.ridesNegotiating,
      priority: input.ridesNegotiating > 0 ? 'priority' : 'normal',
    },
    {
      key: 'food_ready',
      label: 'Đồ ăn sẵn sàng',
      count: input.foodReady,
      priority: input.foodReady > 0 ? 'high' : 'normal',
    },
    {
      key: 'food_in_flight',
      label: 'Đồ ăn đang giao',
      count: input.foodInFlight,
      priority: 'normal',
    },
    {
      key: 'exceptions',
      label: 'Ngoại lệ mở',
      count: input.exceptionsOpen,
      priority: input.exceptionsOpen > 0 ? 'high' : 'normal',
    },
  ];
}

export function deriveSystemAlerts(input: {
  exceptionsOpen: number;
  driversOnline: number;
  foodReady: number;
  ridesNegotiating: number;
  ridesOpen: number;
}): OpsSystemAlert[] {
  const alerts: OpsSystemAlert[] = [];

  if (input.exceptionsOpen > 0) {
    alerts.push({
      code: 'exceptions_open',
      title: 'Ngoại lệ đang mở',
      detail: `${input.exceptionsOpen} ngoại lệ cần theo dõi`,
      severity: input.exceptionsOpen >= 10 ? 'danger' : 'warning',
    });
  }

  if (input.driversOnline === 0 && input.ridesOpen > 0) {
    alerts.push({
      code: 'drivers_online_zero',
      title: 'Không có tài xế online',
      detail: `${input.ridesOpen} chuyến mở trong khi 0 tài xế online`,
      severity: 'danger',
    });
  } else if (input.driversOnline === 0) {
    alerts.push({
      code: 'drivers_online_zero',
      title: 'Không có tài xế online',
      detail: 'Presence hiện không có tài xế online',
      severity: 'warning',
    });
  }

  if (input.foodReady >= 20) {
    alerts.push({
      code: 'food_ready_high',
      title: 'Đơn READY cao',
      detail: `${input.foodReady} đơn đồ ăn đang chờ tài xế lấy`,
      severity: 'warning',
    });
  }

  if (input.ridesNegotiating >= 30) {
    alerts.push({
      code: 'rides_negotiating_high',
      title: 'Thương lượng nhiều',
      detail: `${input.ridesNegotiating} chuyến đang thương lượng giá`,
      severity: 'info',
    });
  }

  if (alerts.length === 0) {
    alerts.push({
      code: 'ops_nominal',
      title: 'Vận hành ổn định',
      detail: 'Không có cảnh báo vận hành từ KPI hiện tại',
      severity: 'success',
    });
  }

  return alerts;
}

export function mergeAreaDemand(
  rideAreas: ReadonlyArray<{ name: string; count: number }>,
  foodAreas: ReadonlyArray<{ name: string; count: number }>,
  limit = 5,
): OpsAreaDemandRow[] {
  const map = new Map<string, number>();
  for (const row of rideAreas) {
    const name = normalizeShortAreaLabel(row.name);
    map.set(name, (map.get(name) ?? 0) + row.count);
  }
  for (const row of foodAreas) {
    const name = normalizeShortAreaLabel(row.name);
    map.set(name, (map.get(name) ?? 0) + row.count);
  }
  return [...map.entries()]
    .map(([name, demand]) => ({ name, demand }))
    .sort((a, b) => b.demand - a.demand || a.name.localeCompare(b.name))
    .slice(0, limit);
}

export function hoursAgoUtc(now: Date, hours: number): Date {
  return new Date(now.getTime() - hours * 3_600_000);
}

function last24LocalHourKeys(now: Date): string[] {
  const keys: string[] = [];
  const offsetMs = OPS_KPI_TODAY_UTC_OFFSET_HOURS * 3_600_000;
  const local = new Date(now.getTime() + offsetMs);
  const alignedLocalMs = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate(),
    local.getUTCHours(),
    0,
    0,
    0,
  );
  for (let i = 23; i >= 0; i -= 1) {
    const bucketLocal = new Date(alignedLocalMs - i * 3_600_000);
    const y = bucketLocal.getUTCFullYear();
    const m = String(bucketLocal.getUTCMonth() + 1).padStart(2, '0');
    const d = String(bucketLocal.getUTCDate()).padStart(2, '0');
    const h = String(bucketLocal.getUTCHours()).padStart(2, '0');
    keys.push(`${y}-${m}-${d}T${h}:00+07:00`);
  }
  return keys;
}

function toHourCountMap(rows: HourlyCountRow[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const row of rows) {
    map.set(row.hourKey, Number(row.cnt));
  }
  return map;
}

function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

function toIso(value: Date | string): string {
  if (value instanceof Date) {
    return value.toISOString();
  }
  return new Date(value).toISOString();
}
