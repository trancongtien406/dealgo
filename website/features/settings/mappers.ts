import type { StatusTone } from "@/lib/admin-format";
import type { AuditResult } from "@/features/settings/types";

const labels: Record<AuditResult, string> = {
  SUCCESS: "Thành công",
  PENDING_APPROVAL: "Chờ duyệt",
  LOGGED: "Đã ghi log",
  REJECTED: "Từ chối",
};
const tones: Record<AuditResult, StatusTone> = {
  SUCCESS: "success",
  PENDING_APPROVAL: "food",
  LOGGED: "delivery",
  REJECTED: "danger",
};

export function auditResultLabel(result: AuditResult) {
  return labels[result];
}
export function auditResultTone(result: AuditResult) {
  return tones[result];
}
