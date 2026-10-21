import type { StatusTone } from "@/lib/admin-format";
import type { PromotionCampaignStatus } from "@/features/promotions/types";

const labels: Record<PromotionCampaignStatus, string> = {
  ACTIVE: "Đang hoạt động",
  RUNNING: "Đang chạy",
  SCHEDULED: "Đã lên lịch",
  UPCOMING: "Sắp diễn ra",
  PAUSED: "Tạm dừng",
  ENDED: "Đã kết thúc",
  CANCELLED: "Đã hủy",
  DRAFT: "Bản nháp",
};

const tones: Record<string, StatusTone> = {
  ACTIVE: "success",
  RUNNING: "success",
  SCHEDULED: "delivery",
  UPCOMING: "delivery",
  PAUSED: "food",
  CANCELLED: "danger",
  DRAFT: "delivery",
  ENDED: "delivery",
};

export function promotionCampaignStatusLabel(status: PromotionCampaignStatus | string): string {
  return labels[status as PromotionCampaignStatus] || status;
}

export function promotionCampaignStatusTone(
  status: PromotionCampaignStatus | string,
): StatusTone {
  return tones[status] || "delivery";
}
