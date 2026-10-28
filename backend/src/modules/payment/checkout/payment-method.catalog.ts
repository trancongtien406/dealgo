import type { PaymentMethodCode, PaymentServiceCode } from '../../../platform/settings/payment-method-registry.js';
import type { PaymentMethodName, PaymentProviderName } from '../payment.constants.js';

export type PaymentMethodGroup = 'WALLET' | 'CARD' | 'RECOMMENDED' | 'ADD_MORE';

export type PaymentMethodCatalogEntry = {
  code: PaymentMethodCode;
  label: string;
  subtitle: string | null;
  group: PaymentMethodGroup;
  /** null = cash (no PSP). */
  provider: PaymentProviderName | null;
  /** payment_intents.method enum value. */
  intentMethod: PaymentMethodName;
  defaultSortOrder: number;
  /** Shown when the method is off and admin left no reason. */
  defaultReason: string;
};

/** Fixed catalog: mirrors the picker sections (Ví điện tử / Thẻ / Đề xuất / Thêm phương thức). */
export const PAYMENT_METHOD_CATALOG: readonly PaymentMethodCatalogEntry[] = [
  { code: 'APPLE_PAY', label: 'Apple Pay', subtitle: null, group: 'WALLET', provider: 'applepay', intentMethod: 'APPLE_PAY', defaultSortOrder: 10, defaultReason: 'Chưa hỗ trợ' },
  { code: 'MOMO', label: 'MoMo', subtitle: null, group: 'WALLET', provider: 'momo', intentMethod: 'MOMO', defaultSortOrder: 20, defaultReason: 'Đang chờ cấp phép' },
  { code: 'VNPAY_ATM', label: 'Thẻ ATM nội địa (Napas)', subtitle: 'Qua VNPAY', group: 'CARD', provider: 'vnpay', intentMethod: 'VNPAY', defaultSortOrder: 30, defaultReason: 'Đang chờ cấp phép' },
  { code: 'CASH', label: 'Tiền mặt', subtitle: 'Hoặc chuyển khoản/QR cho tài xế', group: 'RECOMMENDED', provider: null, intentMethod: 'COD', defaultSortOrder: 40, defaultReason: '' },
  { code: 'DEALGO_WALLET', label: 'Ví DealGo', subtitle: null, group: 'RECOMMENDED', provider: 'wallet', intentMethod: 'DEALGO_WALLET', defaultSortOrder: 50, defaultReason: 'Sắp ra mắt' },
  { code: 'VNPAY', label: 'VNPAY QR', subtitle: 'Quét mã bằng app ngân hàng', group: 'ADD_MORE', provider: 'vnpay', intentMethod: 'VNPAY', defaultSortOrder: 60, defaultReason: 'Đang chờ cấp phép' },
  { code: 'INTERNATIONAL_CARD', label: 'Thẻ quốc tế', subtitle: 'Visa, Mastercard, JCB', group: 'ADD_MORE', provider: 'card', intentMethod: 'CARD', defaultSortOrder: 70, defaultReason: 'Chưa hỗ trợ' },
  { code: 'SHOPEEPAY', label: 'ShopeePay', subtitle: null, group: 'ADD_MORE', provider: 'shopeepay', intentMethod: 'SHOPEEPAY', defaultSortOrder: 80, defaultReason: 'Chưa hỗ trợ' },
  { code: 'ZALOPAY', label: 'ZaloPay', subtitle: null, group: 'ADD_MORE', provider: 'zalopay', intentMethod: 'ZALOPAY', defaultSortOrder: 90, defaultReason: 'Đang chờ cấp phép' },
];

export function catalogEntry(code: PaymentMethodCode): PaymentMethodCatalogEntry {
  return PAYMENT_METHOD_CATALOG.find((m) => m.code === code)!;
}

/** Ride vehicle class → payment service bucket. */
export function serviceForVehicleClass(vehicleClassCode: string | null | undefined): PaymentServiceCode {
  return (vehicleClassCode ?? '').toUpperCase().startsWith('MOTORBIKE') ||
    (vehicleClassCode ?? '').toUpperCase().startsWith('BIKE')
    ? 'BIKE'
    : 'CAR';
}
