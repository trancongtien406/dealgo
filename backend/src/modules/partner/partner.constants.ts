import { isCarVehicleClassCode, vehicleKindOf } from '../ride-vehicle/ride-vehicle-class.js';
export const PARTNER_REPOSITORY = Symbol('PARTNER_REPOSITORY');

export const PARTNER_APPLICATION_ROLES = ['DRIVER', 'MERCHANT'] as const;
export const PARTNER_APPLICATION_STATUSES = [
  'DRAFT',
  'SUBMITTED',
  'IN_REVIEW',
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
    /** t53u liveness clip; t54u: required for drivers, purged after KYC_VIDEO_RETENTION_DAYS. */
    'SELFIE_VIDEO',
  ],
  MERCHANT: [
    'BUSINESS_LICENSE',
    /** t60u: giấy chứng nhận cơ sở đủ điều kiện an toàn thực phẩm (or the small-shop commitment). */
    'FOOD_SAFETY_CERT',
    /**
     * t61u (AGENT_PROPOSED): bản cam kết bảo đảm ATTP — accepted instead of FOOD_SAFETY_CERT
     * only for household businesses (registrationSubject HOUSEHOLD), as GrabFood/ShopeeFood VN do
     * for hộ kinh doanh / small eateries exempt from the certificate.
     */
    'FOOD_SAFETY_COMMITMENT',
    'REP_ID_FRONT',
    'REP_ID_BACK',
    'STOREFRONT',
  ],
} as const;

/**
 * Base kinds that must be on file for every DRIVER (Bike + Car).
 * t54u (DEC-PROD-070): the liveness clip SELFIE_VIDEO is required for drivers.
 * Merchants have no face step, so KYB is unchanged.
 */
export const PARTNER_REQUIRED_DOCUMENTS = {
  DRIVER: ['ID_FRONT', 'ID_BACK', 'SELFIE', 'SELFIE_VIDEO', 'LICENSE', 'VEHICLE_REG'],
  MERCHANT: ['BUSINESS_LICENSE', 'FOOD_SAFETY_CERT', 'REP_ID_FRONT', 'REP_ID_BACK'],
} as const;

/**
 * t60u: the driving-licence class the applicant declares must cover the vehicle class.
 * Covers both the 2024 Road Traffic Law classes (A1, A, B, C1, C, D1, D2, D) and older
 * cards still in circulation (A2, B1, B2, E). Ops still compares it with the photo.
 */
/** RIDE-005: licence classes per vehicle kind (the class's BIKE | CAR kind decides). */
export const LICENSE_CLASSES_FOR_KIND = {
  BIKE: ['A1', 'A', 'A2'],
  CAR: ['B', 'B1', 'B2', 'C1', 'C', 'D1', 'D2', 'D', 'E'],
} as const satisfies Record<'BIKE' | 'CAR', readonly string[]>;

/** Allowed licence classes for a vehicle class code (any catalog class, via its kind). */
export const LICENSE_CLASSES_FOR_VEHICLE: Record<string, readonly string[]> = new Proxy(
  {},
  { get: (_t, code) => (typeof code === 'string' ? LICENSE_CLASSES_FOR_KIND[vehicleKindOf(code)] : undefined) },
);

export function licenseClassCoversVehicle(licenseClass: unknown, vehicleClassCode: string): boolean {
  if (typeof licenseClass !== 'string') return false;
  const allowed: readonly string[] = LICENSE_CLASSES_FOR_KIND[vehicleKindOf(vehicleClassCode)];
  return allowed.includes(licenseClass.trim().toUpperCase());
}

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

/** t53u: the liveness clip is the only video kind; capped at the platform upload ceiling. */
export const PARTNER_VIDEO_DOCUMENT_KINDS = ['SELFIE_VIDEO'] as const;
export const PARTNER_VIDEO_CONTENT_TYPES = ['video/mp4', 'video/quicktime'] as const;
/** t54u: liveness clip cap (KB). The app records ~5 s at a low preset (≈1–3 MB). */
export const PARTNER_VIDEO_MAX_KB = 5120;

/** Room for base DRIVER docs + Car extras (VEHICLE_INSURANCE) + SELFIE_VIDEO. */
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
    isCarVehicleClassCode(opts.vehicleClassCode)
  ) {
    return [...base, ...PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS];
  }
  return base;
}

/** t61u: a household shop may file the ATTP commitment in place of the certificate. */
export const FOOD_SAFETY_ALTERNATIVE_SUBJECTS = ['HOUSEHOLD'] as const;

export function documentAlternatives(
  role: 'DRIVER' | 'MERCHANT',
  opts?: { registrationSubject?: unknown },
): Record<string, readonly string[]> {
  if (
    role === 'MERCHANT' &&
    typeof opts?.registrationSubject === 'string' &&
    (FOOD_SAFETY_ALTERNATIVE_SUBJECTS as readonly string[]).includes(
      opts.registrationSubject.trim().toUpperCase(),
    )
  ) {
    return { FOOD_SAFETY_CERT: ['FOOD_SAFETY_COMMITMENT'] };
  }
  return {};
}

/** Required kinds not on file, counting an accepted alternative as the required kind. */
export function missingPartnerDocuments(
  role: 'DRIVER' | 'MERCHANT',
  onFile: ReadonlySet<string>,
  opts?: { vehicleClassCode?: string; carExtraDocsGate?: boolean; registrationSubject?: unknown },
): string[] {
  const alternatives = documentAlternatives(role, opts);
  return requiredPartnerDocuments(role, opts).filter(
    (kind) => !onFile.has(kind) && !(alternatives[kind] ?? []).some((alt) => onFile.has(alt)),
  );
}

/**
 * t61u: text fields an auto-approval needs (the applicant confirmed them, often prefilled
 * by on-device OCR). Missing any → the case stays in the manual queue.
 */
export const PARTNER_AUTO_APPROVE_FIELDS = {
  DRIVER: ['fullName', 'birthDate', 'idNumber', 'licenseNumber', 'licenseClass', 'vehiclePlate'],
  MERCHANT: ['shopName', 'shopAddress', 'representativeName'],
} as const;
