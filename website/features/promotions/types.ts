export const PROMOTION_CAMPAIGN_STATUSES = [
  "ACTIVE",
  "RUNNING",
  "SCHEDULED",
  "UPCOMING",
  "PAUSED",
  "ENDED",
  "CANCELLED",
  "DRAFT",
] as const;

export type PromotionCampaignStatus =
  (typeof PROMOTION_CAMPAIGN_STATUSES)[number];
