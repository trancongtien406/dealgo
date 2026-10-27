export const PARTNER_REPOSITORY = Symbol('PARTNER_REPOSITORY');

export const PARTNER_APPLICATION_ROLES = ['DRIVER', 'MERCHANT'] as const;
export const PARTNER_APPLICATION_STATUSES = [
  'DRAFT',
  'SUBMITTED',
  'APPROVED',
  'REJECTED',
] as const;

/** Document kinds an applicant may upload, per role (DEC-PROD-020). */
export const PARTNER_DOCUMENT_KINDS = {
  DRIVER: [
    'ID_FRONT',
    'ID_BACK',
    'SELFIE',
    'LICENSE',
    'VEHICLE_REG',
    /** OPEN-006 scaffold — Car checklist only; not a regulatory determination. */
    'VEHICLE_INSURANCE',
  ],
  MERCHANT: ['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK', 'STOREFRONT'],
} as const;

/** Base kinds that must be on file for every DRIVER (Bike + Car). */
export const PARTNER_REQUIRED_DOCUMENTS = {
  DRIVER: ['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'],
  MERCHANT: ['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK'],
} as const;

/**
 * Extra DRIVER docs required for Car classes when PARTNER_CAR_KYC_EXTRA_DOCS gate is on.
 * OPEN-006 scaffold — checklist only; owner loads real policy/secrets later.
 */
export const PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS = ['VEHICLE_INSURANCE'] as const;

/** Sections ops can flag when asking the applicant to fix a submission. */
export const PARTNER_ISSUE_SECTIONS = {
  DRIVER: ['PERSONAL', 'ID_CARD', 'SELFIE', 'LICENSE', 'VEHICLE', 'BANK', 'OTHER'],
  MERCHANT: ['SHOP_INFO', 'REPRESENTATIVE', 'BUSINESS_DOCS', 'STOREFRONT', 'BANK', 'OTHER'],
} as const;

export const ALL_PARTNER_DOCUMENT_KINDS = [
  ...PARTNER_DOCUMENT_KINDS.DRIVER,
  ...PARTNER_DOCUMENT_KINDS.MERCHANT,
] as const;

export const ALL_PARTNER_ISSUE_SECTIONS = [
  ...new Set([...PARTNER_ISSUE_SECTIONS.DRIVER, ...PARTNER_ISSUE_SECTIONS.MERCHANT]),
] as const;

/** Room for base DRIVER docs + Car extras (VEHICLE_INSURANCE). */
export const PARTNER_MAX_DOCUMENTS_PER_REQUEST = 8;

export function requiredPartnerDocuments(
  role: 'DRIVER' | 'MERCHANT',
  opts?: { vehicleClassCode?: string; carExtraDocsGate?: boolean },
): readonly string[] {
  if (role === 'MERCHANT') {
    return PARTNER_REQUIRED_DOCUMENTS.MERCHANT;
  }
  const base = PARTNER_REQUIRED_DOCUMENTS.DRIVER as readonly string[];
  if (
    opts?.carExtraDocsGate &&
    opts.vehicleClassCode &&
    (opts.vehicleClassCode === 'CAR_4' || opts.vehicleClassCode === 'CAR_7')
  ) {
    return [...base, ...PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS];
  }
  return base;
}
