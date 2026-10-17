import type { StatusTone } from "@/lib/admin-format";
import type {
  CmsStatus,
  NotificationCampaignStatus,
} from "@/features/notifications/types";

const campaignLabels: Record<NotificationCampaignStatus, string> = {
  SENDING: "Đang gửi",
  SENT: "Đã gửi",
  RUNNING: "Đang chạy",
  PENDING_APPROVAL: "Chờ duyệt",
  DRAFT: "Bản nháp",
};

const cmsLabels: Record<CmsStatus, string> = {
  PUBLISHED: "Đã đăng",
  IN_REVIEW: "Đang duyệt",
  DRAFT: "Bản nháp",
};

export function notificationCampaignStatusLabel(
  status: NotificationCampaignStatus,
) {
  return campaignLabels[status];
}
export function cmsStatusLabel(status: CmsStatus) {
  return cmsLabels[status];
}
export function isQuietCampaignStatus(status: NotificationCampaignStatus) {
  return status === "DRAFT";
}
export function campaignStatusTone(
  status: NotificationCampaignStatus,
): StatusTone | "quiet" {
  if (status === "DRAFT") return "quiet";
  if (status === "PENDING_APPROVAL") return "food";
  return "success";
}
export const notificationCampaignStatusTone = campaignStatusTone;

export function cmsStatusTone(status: CmsStatus): StatusTone | "quiet" {
  if (status === "DRAFT") return "quiet";
  if (status === "IN_REVIEW") return "food";
  return "success";
}

export const tabLabels: Record<string, string> = {
  ALL: "Tất cả",
  RUNNING: "Đang chạy",
  SENT: "Đã gửi",
  PENDING: "Chờ duyệt",
  DRAFT: "Bản nháp",
};
