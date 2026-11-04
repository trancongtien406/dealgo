import type { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../../platform/config/env.js';
import {
  MomoAdapter,
  PayosAdapter,
  StubPaymentAdapter,
  VnpayAdapter,
  ZalopayAdapter,
  type HttpPost,
  type PaymentAdapter,
} from '../../../integrations/payment-gateways/providers/index.js';
import type { PaymentProviderName } from '../payment.constants.js';

export const PAYMENT_ADAPTERS = Symbol('PAYMENT_ADAPTERS');

export type PaymentAdapterMap = Partial<Record<PaymentProviderName, PaymentAdapter>>;

export type PaymentGatewayEnv = Partial<
  Pick<
    AppEnv,
    | 'VNPAY_TMN_CODE'
    | 'VNPAY_HASH_SECRET'
    | 'VNPAY_URL'
    | 'VNPAY_API_URL'
    | 'MOMO_PARTNER_CODE'
    | 'MOMO_ACCESS_KEY'
    | 'MOMO_SECRET_KEY'
    | 'MOMO_ENDPOINT'
    | 'ZALOPAY_APP_ID'
    | 'ZALOPAY_KEY1'
    | 'ZALOPAY_KEY2'
    | 'ZALOPAY_ENDPOINT'
    | 'PAYOS_CLIENT_ID'
    | 'PAYOS_API_KEY'
    | 'PAYOS_CHECKSUM_KEY'
    | 'PAYOS_ENDPOINT'
  >
>;

export function buildPaymentAdapters(env: PaymentGatewayEnv, http?: HttpPost): PaymentAdapterMap {
  return {
    momo: new MomoAdapter(
      {
        partnerCode: env.MOMO_PARTNER_CODE,
        accessKey: env.MOMO_ACCESS_KEY,
        secretKey: env.MOMO_SECRET_KEY,
        endpoint: env.MOMO_ENDPOINT,
      },
      http,
    ),
    zalopay: new ZalopayAdapter(
      {
        appId: env.ZALOPAY_APP_ID,
        key1: env.ZALOPAY_KEY1,
        key2: env.ZALOPAY_KEY2,
        endpoint: env.ZALOPAY_ENDPOINT,
      },
      http,
    ),
    vnpay: new VnpayAdapter(
      {
        tmnCode: env.VNPAY_TMN_CODE,
        hashSecret: env.VNPAY_HASH_SECRET,
        url: env.VNPAY_URL,
        apiUrl: env.VNPAY_API_URL,
      },
      http,
    ),
    payos: new PayosAdapter({
      clientId: env.PAYOS_CLIENT_ID,
      apiKey: env.PAYOS_API_KEY,
      checksumKey: env.PAYOS_CHECKSUM_KEY,
      endpoint: env.PAYOS_ENDPOINT,
    }),
    shopeepay: new StubPaymentAdapter(
      'shopeepay',
      ['SHOPEEPAY_CLIENT_ID', 'SHOPEEPAY_SECRET_KEY', 'SHOPEEPAY_MERCHANT_EXT_ID', 'SHOPEEPAY_ENDPOINT'],
      'ShopeePay',
    ),
    card: new StubPaymentAdapter('card', ['CARD_GATEWAY_MERCHANT_ID', 'CARD_GATEWAY_SECRET'], 'International card'),
    applepay: new StubPaymentAdapter('applepay', ['APPLE_PAY_MERCHANT_ID'], 'Apple Pay'),
  };
}

export function paymentAdaptersFromConfig(config: ConfigService<AppEnv, true>): PaymentAdapterMap {
  const get = <K extends keyof PaymentGatewayEnv>(key: K) =>
    config.get(key as keyof AppEnv, { infer: true }) as PaymentGatewayEnv[K];
  return buildPaymentAdapters({
    VNPAY_TMN_CODE: get('VNPAY_TMN_CODE'),
    VNPAY_HASH_SECRET: get('VNPAY_HASH_SECRET'),
    VNPAY_URL: get('VNPAY_URL'),
    VNPAY_API_URL: get('VNPAY_API_URL'),
    MOMO_PARTNER_CODE: get('MOMO_PARTNER_CODE'),
    MOMO_ACCESS_KEY: get('MOMO_ACCESS_KEY'),
    MOMO_SECRET_KEY: get('MOMO_SECRET_KEY'),
    MOMO_ENDPOINT: get('MOMO_ENDPOINT'),
    ZALOPAY_APP_ID: get('ZALOPAY_APP_ID'),
    ZALOPAY_KEY1: get('ZALOPAY_KEY1'),
    ZALOPAY_KEY2: get('ZALOPAY_KEY2'),
    ZALOPAY_ENDPOINT: get('ZALOPAY_ENDPOINT'),
    PAYOS_CLIENT_ID: get('PAYOS_CLIENT_ID'),
    PAYOS_API_KEY: get('PAYOS_API_KEY'),
    PAYOS_CHECKSUM_KEY: get('PAYOS_CHECKSUM_KEY'),
    PAYOS_ENDPOINT: get('PAYOS_ENDPOINT'),
  });
}
