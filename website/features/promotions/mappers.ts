import type { StatusTone } from "@/lib/admin-format";
import type { PromotionCampaignStatus } from "@/features/promotions/types";

const labels: Record<PromotionCampaignStatus, string> = {
  RUNNING: "Đang chạy",
  UPCOMING: "Sắp diễn ra",
  ENDED: "Đã kết thúc",
  PAUSED: "Tạm dừng",
};
const tones: Record<Exclude<PromotionCampaignStatus, "ENDED">, StatusTone> = {
  RUNNING: "success",
  UPCOMING: "delivery",
  PAUSED: "food",
};

export function promotionCampaignStatusLabel(status: PromotionCampaignStatus) {
  return labels[status];
}
export function promotionCampaignStatusTone(
  status: Exclude<PromotionCampaignStatus, "ENDED">,
) {
  return tones[status];
}
