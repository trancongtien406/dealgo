import type { StatusTone } from "@/lib/admin-format";
import type {
  NestExceptionItem,
  NestExceptionReason,
} from "@/features/exceptions/nest-types";
import type {
  ExceptionCase,
  ExceptionStatus,
} from "@/features/exceptions/types";

import { formatOpsDateTime } from "@/lib/ops-time";

export function mapNestExceptionToCase(item: NestExceptionItem): ExceptionCase {
  const domain = item.kind === "ride" ? "RIDE" : "FOOD";
  const prefix = item.kind === "ride" ? "RD" : "FD";
  return {
    code: item.id,
    title: exceptionTitle(item),
    domain,
    status: nestReasonToStatus(item.reason),
    priority: item.reason === "stuck" ? "P1" : "P2",
    openedAt: formatOpsDateTime(item.updatedAt),
    entityRef: `${prefix}-${shortId(item.id)} · ${item.status}`,
  };
}

export function nestReasonToStatus(
  reason: NestExceptionReason,
): ExceptionStatus {
  return reason === "stuck" ? "OPEN" : "ESCALATED";
}

const statusLabels: Record<ExceptionStatus, string> = {
  OPEN: "Đang mở",
  IN_PROGRESS: "Đang xử lý",
  RESOLVED: "Đã giải quyết",
  ESCALATED: "Đã leo thang",
};

const statusTones: Record<ExceptionStatus, StatusTone> = {
  OPEN: "danger",
  IN_PROGRESS: "food",
  RESOLVED: "success",
  ESCALATED: "brand",
};

const priorityLabels: Record<ExceptionCase["priority"], string> = {
  P1: "P1",
  P2: "P2",
  P3: "P3",
};

const priorityTones: Record<ExceptionCase["priority"], StatusTone> = {
  P1: "danger",
  P2: "food",
  P3: "delivery",
};

const domainLabels: Record<ExceptionCase["domain"], string> = {
  RIDE: "Chuyến xe",
  FOOD: "Đồ ăn",
  OTHER: "Khác",
};

export function exceptionStatusLabel(status: ExceptionStatus): string {
  return statusLabels[status];
}

export function exceptionStatusTone(status: ExceptionStatus): StatusTone {
  return statusTones[status];
}

export function exceptionPriorityLabel(
  priority: ExceptionCase["priority"],
): string {
  return priorityLabels[priority];
}

export function exceptionPriorityTone(
  priority: ExceptionCase["priority"],
): StatusTone {
  return priorityTones[priority];
}

export function exceptionDomainLabel(domain: ExceptionCase["domain"]): string {
  return domainLabels[domain];
}

export const exceptionStatusFilterOptions = [
  { value: "ALL" as const, label: "Tất cả trạng thái" },
  { value: "OPEN" as const, label: statusLabels.OPEN },
  { value: "IN_PROGRESS" as const, label: statusLabels.IN_PROGRESS },
  { value: "RESOLVED" as const, label: statusLabels.RESOLVED },
  { value: "ESCALATED" as const, label: statusLabels.ESCALATED },
];

/**
 * Nest list uses entity id as case `code`; fixtures use EX-* with the
 * ride/food display code in `entityRef`.
 */
export function exceptionEntityCode(item: ExceptionCase): string {
  if (item.code.startsWith("EX-")) {
    const fromRef = item.entityRef.split(/\s*·\s*/)[0]?.trim();
    return fromRef || item.code;
  }
  return item.code;
}

export function exceptionEntityHref(item: ExceptionCase): string | null {
  if (item.domain === "RIDE") {
    return `/rides/${exceptionEntityCode(item)}`;
  }
  if (item.domain === "FOOD") {
    return `/food-orders/${exceptionEntityCode(item)}`;
  }
  return null;
}

function exceptionTitle(item: NestExceptionItem): string {
  const entity = item.kind === "ride" ? "Chuyến" : "Đơn food";
  if (item.reason === "stuck") {
    return `${entity} kẹt ở ${item.status}`;
  }
  return `${entity} kết thúc bất thường (${item.status})`;
}

function shortId(id: string): string {
  const compact = id.replace(/-/g, "");
  return compact.slice(0, 8).toUpperCase();
}
