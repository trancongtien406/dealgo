import type { StatusTone } from "@/lib/admin-format";
import type { StoreApprovalStatus } from "@/features/store-approvals/types";

const labels: Record<StoreApprovalStatus, string> = {
  PENDING_KYB: "Chờ KYB",
  NEEDS_VERIFY: "Cần xác minh",
  APPROVED: "Đã duyệt",
  REJECTED: "Từ chối",
};
const tones: Record<StoreApprovalStatus, StatusTone> = {
  PENDING_KYB: "food",
  NEEDS_VERIFY: "danger",
  APPROVED: "success",
  REJECTED: "danger",
};

export function storeApprovalStatusLabel(status: StoreApprovalStatus) {
  return labels[status];
}
export function storeApprovalStatusTone(status: StoreApprovalStatus) {
  return tones[status];
}
