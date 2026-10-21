export const STORE_APPROVAL_STATUSES = [
  "PENDING_KYB",
  "NEEDS_VERIFY",
  "APPROVED",
  "REJECTED",
] as const;
export type StoreApprovalStatus = (typeof STORE_APPROVAL_STATUSES)[number];

export type StoreApproval = {
  code: string;
  initials: string;
  name: string;
  category: string;
  owner: string;
  phoneMasked: string;
  address: string;
  area: string;
  registrationType: string;
  submittedAt: string;
  status: StoreApprovalStatus;
  saleReady: boolean;
  assignee: string;
  documents: import("@/features/kyc/partner-review").PartnerDocument[];
  reason: string | null;
  issues: import("@/features/kyc/partner-review").PartnerIssue[];
};
