export const PROMOTION_CAMPAIGN_STATUSES = [
  "RUNNING",
  "UPCOMING",
  "ENDED",
  "PAUSED",
] as const;
export type PromotionCampaignStatus =
  (typeof PROMOTION_CAMPAIGN_STATUSES)[number];
