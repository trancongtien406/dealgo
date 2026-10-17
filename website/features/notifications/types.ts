export const NOTIFICATION_CAMPAIGN_STATUSES = [
  "SENDING",
  "SENT",
  "RUNNING",
  "PENDING_APPROVAL",
  "DRAFT",
] as const;
export type NotificationCampaignStatus =
  (typeof NOTIFICATION_CAMPAIGN_STATUSES)[number];

export const CMS_STATUSES = ["PUBLISHED", "IN_REVIEW", "DRAFT"] as const;
export type CmsStatus = (typeof CMS_STATUSES)[number];

export type CmsItem = {
  id: string;
  title: string;
  kind: string;
  body?: string;
  date: string;
  status: CmsStatus;
  icon: string;
  tone: "brand" | "food" | "delivery" | "success" | "danger";
};
