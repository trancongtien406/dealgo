export const PAYMENT_PORT = Symbol('PAYMENT_PORT');
export const PAYMENT_REPOSITORY = Symbol('PAYMENT_REPOSITORY');
export const CHECKOUT_REPOSITORY = Symbol('CHECKOUT_REPOSITORY');

export type PaymentEntityTypeName = 'RIDE' | 'FOOD_ORDER';
/** Mirrors the Prisma PaymentMethod enum. DEALGO_WALLET is kept only for historical rows; the method is not offered. */
export type PaymentMethodName =
  | 'COD'
  | 'VNPAY'
  | 'MOMO'
  | 'ZALOPAY'
  | 'SHOPEEPAY'
  | 'CARD'
  | 'APPLE_PAY'
  | 'DEALGO_WALLET';
export type PaymentIntentStatusName =
  | 'SANDBOX_RECORDED'
  | 'CREATED'
  | 'PENDING_REDIRECT'
  | 'CAPTURED_STUB'
  | 'CAPTURED'
  | 'FAILED'
  | 'EXPIRED'
  | 'REFUND_PENDING'
  | 'REFUNDED';
export type PaymentProviderName =
  | 'sandbox'
  | 'vnpay'
  | 'momo'
  | 'zalopay'
  | 'shopeepay'
  | 'card'
  | 'applepay'
  | 'payos'
  | 'wallet';
