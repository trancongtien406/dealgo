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
  DRIVER: ['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'],
  MERCHANT: ['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK', 'STOREFRONT'],
} as const;

/** Kinds that must be on file (new upload or kept from the previous submission). */
export const PARTNER_REQUIRED_DOCUMENTS = {
  DRIVER: ['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'],
  MERCHANT: ['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK'],
} as const;

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

export const PARTNER_MAX_DOCUMENTS_PER_REQUEST = 6;
