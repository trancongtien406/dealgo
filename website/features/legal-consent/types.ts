export type LegalSlug = "terms" | "privacy" | "regulations";
export type LegalRole = "CUSTOMER" | "DRIVER" | "MERCHANT";

export const LEGAL_SLUG_LABELS: Record<LegalSlug, string> = { terms: "Điều khoản sử dụng", privacy: "Chính sách quyền riêng tư", regulations: "Quy chế sử dụng (tài xế & cửa hàng)" };
export const LEGAL_ROLE_LABELS: Record<LegalRole, string> = { CUSTOMER: "Khách hàng", DRIVER: "Tài xế", MERCHANT: "Cửa hàng" };

export type LegalPolicyVersion = {
  id: string;
  slug: string;
  version: number;
  title: string;
  changelog: string;
  effectiveAt: string | null;
  audienceRoles: string[];
  requiresConsent: boolean;
  publishedAt: string;
  emailStatus: "NONE" | "QUEUED" | "SENDING" | "SENT" | string;
  emailQueuedAt: string | null;
  emailRecipients: number | null;
  emailSentCount: number;
  emailFailedCount: number;
  consentCount?: number;
};

export type PublishLegalVersionInput = {
  slug: LegalSlug;
  changelog: string;
  effectiveAt?: string;
  audienceRoles: LegalRole[];
};

export const EMAIL_STATUS_LABELS: Record<string, string> = {
  NONE: "Chưa gửi",
  QUEUED: "Đã xếp hàng",
  SENDING: "Đang gửi",
  SENT: "Đã gửi",
};
