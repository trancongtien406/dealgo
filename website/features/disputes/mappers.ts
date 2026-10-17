import type { StatusTone } from "@/lib/admin-format";
import type { DisputePriority, DisputeStatus } from "@/features/disputes/types";

const statusLabels: Record<DisputeStatus, string> = {
  OPEN: "Đang xử lý",
  AWAITING_RESPONSE: "Chờ phản hồi",
  INVESTIGATING: "Đang xác minh",
  RESOLVED: "Đã giải quyết",
  PENDING: "Chờ xử lý",
};

const statusTones: Record<DisputeStatus, StatusTone> = {
  OPEN: "food",
  AWAITING_RESPONSE: "delivery",
  INVESTIGATING: "brand",
  RESOLVED: "success",
  PENDING: "delivery",
};

const priorityLabels: Record<DisputePriority, string> = {
  HIGH: "Cao",
  MEDIUM: "Trung bình",
  LOW: "Thấp",
};

const priorityTones: Record<DisputePriority, StatusTone> = {
  HIGH: "danger",
  MEDIUM: "food",
  LOW: "success",
};

export function disputeStatusLabel(status: DisputeStatus): string {
  return statusLabels[status];
}

export function disputeStatusTone(status: DisputeStatus): StatusTone {
  return statusTones[status];
}

export function disputePriorityLabel(priority: DisputePriority): string {
  return priorityLabels[priority];
}

export function disputePriorityTone(priority: DisputePriority): StatusTone {
  return priorityTones[priority];
}
