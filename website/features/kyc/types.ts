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
};
