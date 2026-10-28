/**
 * Shape of the PAYMENT_METHOD_REGISTRY platform setting (admin-editable). Kept in the platform
 * layer so the settings service can validate it without importing the payment module.
 */
export const PAYMENT_METHOD_CODES = [
  'CASH',
  'MOMO',
  'ZALOPAY',
  'VNPAY',
  'VNPAY_ATM',
  'SHOPEEPAY',
  'INTERNATIONAL_CARD',
  'APPLE_PAY',
  'DEALGO_WALLET',
] as const;
export type PaymentMethodCode = (typeof PAYMENT_METHOD_CODES)[number];

export const PAYMENT_SERVICES = ['BIKE', 'CAR', 'FOOD'] as const;
export type PaymentServiceCode = (typeof PAYMENT_SERVICES)[number];

export type PaymentMethodRegistryEntry = {
  services: Record<PaymentServiceCode, boolean>;
  sortOrder: number;
  /** Shown under a disabled row (e.g. "Đang chờ cấp phép"). Null = generic text. */
  unsupportedReason: string | null;
};

export type PaymentMethodRegistryValue = {
  methods: Partial<Record<PaymentMethodCode, PaymentMethodRegistryEntry>>;
};

export function isPaymentMethodCode(value: unknown): value is PaymentMethodCode {
  return typeof value === 'string' && (PAYMENT_METHOD_CODES as readonly string[]).includes(value);
}

export function isPaymentServiceCode(value: unknown): value is PaymentServiceCode {
  return typeof value === 'string' && (PAYMENT_SERVICES as readonly string[]).includes(value);
}

/** Returns a human-readable problem, or null when the value is a valid registry. */
export function validatePaymentMethodRegistry(parsed: unknown): string | null {
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return 'PAYMENT_METHOD_REGISTRY must be an object {"methods": {...}}';
  }
  const methods = (parsed as { methods?: unknown }).methods;
  if (!methods || typeof methods !== 'object' || Array.isArray(methods)) {
    return 'PAYMENT_METHOD_REGISTRY.methods must be an object';
  }
  for (const [code, raw] of Object.entries(methods as Record<string, unknown>)) {
    if (!isPaymentMethodCode(code)) {
      return `Unknown payment method ${code}`;
    }
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      return `${code} must be an object`;
    }
    const entry = raw as Record<string, unknown>;
    const services = entry.services;
    if (services !== undefined) {
      if (!services || typeof services !== 'object' || Array.isArray(services)) {
        return `${code}.services must be an object`;
      }
      for (const [svc, flag] of Object.entries(services as Record<string, unknown>)) {
        if (!isPaymentServiceCode(svc) || typeof flag !== 'boolean') {
          return `${code}.services.${svc} must be BIKE/CAR/FOOD: boolean`;
        }
      }
    }
    if (
      entry.sortOrder !== undefined &&
      (!Number.isInteger(entry.sortOrder) || (entry.sortOrder as number) < 0 || (entry.sortOrder as number) > 999)
    ) {
      return `${code}.sortOrder must be an integer 0..999`;
    }
    if (
      entry.unsupportedReason !== undefined &&
      entry.unsupportedReason !== null &&
      (typeof entry.unsupportedReason !== 'string' || entry.unsupportedReason.length > 160)
    ) {
      return `${code}.unsupportedReason must be a string of at most 160 characters`;
    }
  }
  return null;
}

/** Fills defaults; CASH stays enabled for every service (cash-only fallback). */
export function normalizePaymentMethodRegistry(parsed: unknown): PaymentMethodRegistryValue {
  const out: PaymentMethodRegistryValue = { methods: {} };
  const methods = ((parsed as { methods?: Record<string, Record<string, unknown>> })?.methods ??
    {}) as Record<string, Record<string, unknown>>;
  for (const [code, entry] of Object.entries(methods)) {
    if (!isPaymentMethodCode(code)) {
      continue;
    }
    const services = (entry.services ?? {}) as Partial<Record<PaymentServiceCode, boolean>>;
    const reason =
      typeof entry.unsupportedReason === 'string' && entry.unsupportedReason.trim()
        ? entry.unsupportedReason.trim()
        : null;
    out.methods[code] = {
      services: {
        BIKE: code === 'CASH' ? true : services.BIKE === true,
        CAR: code === 'CASH' ? true : services.CAR === true,
        FOOD: code === 'CASH' ? true : services.FOOD === true,
      },
      sortOrder: Number.isInteger(entry.sortOrder) ? (entry.sortOrder as number) : 100,
      unsupportedReason: reason,
    };
  }
  return out;
}
