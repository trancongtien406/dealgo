export const KYC_STATUSES = [
  "UNDER_REVIEW",
  "IN_REVIEW",
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
  /** DRIVER only: MOTORBIKE | CAR_4 | CAR_7 from the application (DEC-PROD-048). */
  vehicleClassCode: string | null;
  /** Submitted while the admin KYC/KYB switch was OFF (DEC-PROD-048). */
  documentsWaived: boolean;
  status: KycStatus;
  activity: string;
  activated: boolean;
  /** Applicant-entered fields for review, label → value (bank number masked). */
  details: Array<[string, string]>;
  documents: import("@/features/kyc/partner-review").PartnerDocument[];
  reason: string | null;
  issues: import("@/features/kyc/partner-review").PartnerIssue[];
  reviewedAt: string | null;
  /** t52u: device capture checks + server AI pre-check — advisory only, never a decision. */
  checks: import("@/features/kyc/review-checks").KycReviewChecks;
  /** t61u: fields read on-device (OCR) and confirmed/edited by the applicant. */
  ocrFields: import("@/features/kyc/ocr-fields").OcrField[];
  /** t61u: approved by the system (KYC_AUTO_APPROVE_* on). */
  autoApproved: boolean;
  /** t61u: why auto-approve did not apply (manual queue). */
  autoApproveSkipped: string[];
};
