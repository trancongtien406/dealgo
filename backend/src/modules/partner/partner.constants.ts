export const PARTNER_REPOSITORY = Symbol('PARTNER_REPOSITORY');
export const KYC_STORAGE = Symbol('KYC_STORAGE');

export const PARTNER_APPLICATION_ROLES = ['DRIVER', 'MERCHANT'] as const;
export const PARTNER_APPLICATION_STATUSES = [
  'DRAFT',
  'SUBMITTED',
  'APPROVED',
  'REJECTED',
] as const;
