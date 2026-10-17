export const PAYMENT_PORT = Symbol('PAYMENT_PORT');
export const PAYMENT_REPOSITORY = Symbol('PAYMENT_REPOSITORY');

export type PaymentEntityTypeName = 'RIDE' | 'FOOD_ORDER';
export type PaymentMethodName = 'COD' | 'VNPAY' | 'MOMO';
export type PaymentIntentStatusName =
  | 'SANDBOX_RECORDED'
  | 'CREATED'
  | 'PENDING_REDIRECT'
  | 'CAPTURED_STUB';
export type PaymentProviderName = 'sandbox' | 'vnpay' | 'momo';
