export const PAYMENT_GATEWAY_OPTIONS = Symbol('PAYMENT_GATEWAY_OPTIONS');

export type PaymentGatewayOptions = {
  /** Public HTTPS base for IPN + return URLs; online methods stay unavailable without it. */
  publicBaseUrl: string | null;
  /** App deeplink the return page redirects to (e.g. dealgo://payment-return). */
  appReturnUrl: string | null;
};
