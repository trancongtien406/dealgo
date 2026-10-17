import type { StatusTone } from "@/lib/admin-format";
import type { ModerationStatus } from "@/features/catalog-moderation/types";

const labels: Record<ModerationStatus, string> = {
  PENDING: "Chờ duyệt",
  APPROVED: "Đã duyệt",
  REJECTED: "Từ chối",
  NEEDS_REVISION: "Cần chỉnh sửa",
};
const tones: Record<ModerationStatus, StatusTone> = {
  PENDING: "food",
  APPROVED: "success",
  REJECTED: "danger",
  NEEDS_REVISION: "delivery",
};

export function moderationStatusLabel(status: ModerationStatus) {
  return labels[status];
}
export function moderationStatusTone(status: ModerationStatus) {
  return tones[status];
}
