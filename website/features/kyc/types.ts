export const KYC_STATUSES = [
  "UNDER_REVIEW",
  "NEEDS_MORE_INFO",
  "APPROVED",
  "REJECTED",
  "PRIORITY",
] as const;

export type KycStatus = (typeof KYC_STATUSES)[number];

export type KycCase = {
  code: string;
  role: import("@/features/kyc/nest-types").NestPartnerRole;
  initials: string;
  name: string;
  submittedAt: string;
  phoneMasked: string;
  area: string;
  vehicleKind: string;
  vehicle: string;
  plate: string;
  status: KycStatus;
  activity: string;
  activated: boolean;
  /** Applicant-entered fields for review, label → value (bank number masked). */
  details: Array<[string, string]>;
  documents: import("@/features/kyc/partner-review").PartnerDocument[];
  reason: string | null;
  issues: import("@/features/kyc/partner-review").PartnerIssue[];
  reviewedAt: string | null;
};
