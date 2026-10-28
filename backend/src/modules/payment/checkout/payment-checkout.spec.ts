import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import type { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import {
  normalizePaymentMethodRegistry,
  validatePaymentMethodRegistry,
} from '../../../platform/settings/payment-method-registry.js';
import type { HttpPost } from '../../../integrations/payment-gateways/providers/index.js';
import { LedgerService } from '../../ledger/ledger.service.js';
import { MemoryLedgerRepository } from '../../ledger/ledger.repository.js';
import { MemoryCheckoutRepository } from './checkout.repository.js';
import { buildPaymentAdapters } from './payment-adapters.js';
import { PaymentGatewayService, toCheckoutStatus } from './payment-gateway.service.js';
import { PaymentMethodRegistryService } from './payment-method-registry.service.js';
import { serviceForVehicleClass } from './payment-method.catalog.js';

class FakeSettings {
  values: Record<string, string> = { PAYMENT_METHOD_REGISTRY: '{"methods":{}}', PAYMENT_WALLET_ENABLED: 'false' };
  patches: { key: string; value: string; reason: string }[] = [];
  async getJson(key: string) {
    return JSON.parse(this.values[key]!);
  }
  async getBoolean(key: string) {
    return JSON.parse(this.values[key]!) === true;
  }
  async patch(key: string, value: string, reason: string) {
    if (key === 'PAYMENT_METHOD_REGISTRY') {
      const problem = validatePaymentMethodRegistry(JSON.parse(value));
      if (problem) throw new Error(problem);
      value = JSON.stringify(normalizePaymentMethodRegistry(JSON.parse(value)));
    }
    this.values[key] = value;
    this.patches.push({ key, value, reason });
    return {};
  }
}

const ENV = {
  MOMO_PARTNER_CODE: 'MOMOTEST', MOMO_ACCESS_KEY: 'ak', MOMO_SECRET_KEY: 'sk', MOMO_ENDPOINT: 'https://test-payment.momo.vn',
  ZALOPAY_APP_ID: '2553', ZALOPAY_KEY1: 'k1', ZALOPAY_KEY2: 'k2', ZALOPAY_ENDPOINT: 'https://sb-openapi.zalopay.vn',
  VNPAY_TMN_CODE: 'TMN', VNPAY_HASH_SECRET: 'hs', VNPAY_URL: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
  VNPAY_API_URL: 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction',
};

const RIDE = '11111111-1111-4111-8111-111111111111';

function setup(opts: { env?: Partial<typeof ENV>; publicBaseUrl?: string | null; http?: HttpPost } = {}) {
  const settings = new FakeSettings();
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  const http: HttpPost =
    opts.http ??
    (async (url, body) => {
      calls.push({ url, body });
      if (url.endsWith('/v2/create')) return { return_code: 1, order_url: 'https://zalo/pay' };
      if (url.endsWith('/refund')) return { resultCode: 0, return_code: 1 };
      return { resultCode: 0, payUrl: 'https://momo/pay', deeplink: 'momo://pay' };
    });
  const adapters = buildPaymentAdapters(opts.env ?? ENV, http);
  const options = { publicBaseUrl: opts.publicBaseUrl === undefined ? 'https://api.test' : opts.publicBaseUrl, appReturnUrl: 'dealgo://payment-return' };
  const registry = new PaymentMethodRegistryService(settings as unknown as PlatformSettingsService, adapters, options);
  const repo = new MemoryCheckoutRepository();
  const ledgerRepo = new MemoryLedgerRepository();
  const ledger = new LedgerService(ledgerRepo);
  const gateway = new PaymentGatewayService(repo, adapters, options, registry, ledger);
  return { settings, registry, repo, ledger, ledgerRepo, gateway, calls };
}

async function enable(registry: PaymentMethodRegistryService, code: string, services = { BIKE: true, CAR: true, FOOD: true }) {
  await registry.update({ methods: [{ code: code as never, services }] }, 'test enable', 'ops-1');
}

function momoIpn(orderId: string, amount: number, resultCode = 0, transId = 999) {
  const p: Record<string, unknown> = {
    partnerCode: 'MOMOTEST', orderId, requestId: orderId, amount, orderInfo: 'x', orderType: 'momo_wallet',
    transId, resultCode, message: 'm', payType: 'qr', responseTime: 1, extraData: '',
  };
  const raw = `accessKey=ak&amount=${amount}&extraData=&message=m&orderId=${orderId}&orderInfo=x&orderType=momo_wallet&partnerCode=MOMOTEST&payType=qr&requestId=${orderId}&responseTime=1&resultCode=${resultCode}&transId=${transId}`;
  p.signature = createHmac('sha256', 'sk').update(raw).digest('hex');
  return p;
}

describe('registry validation', () => {
  it('rejects unknown codes/bad shapes and forces CASH on', () => {
    expect(validatePaymentMethodRegistry({ methods: { BITCOIN: {} } })).toMatch(/Unknown/);
    expect(validatePaymentMethodRegistry({ methods: { MOMO: { services: { BIKE: 'yes' } } } })).toMatch(/boolean/);
    expect(validatePaymentMethodRegistry([])).toMatch(/object/);
    expect(validatePaymentMethodRegistry({ methods: { MOMO: { sortOrder: 5 } } })).toBeNull();
    const n = normalizePaymentMethodRegistry({ methods: { CASH: { services: { BIKE: false } } } });
    expect(n.methods.CASH!.services).toEqual({ BIKE: true, CAR: true, FOOD: true });
  });

  it('maps vehicle classes to services', () => {
    expect(serviceForVehicleClass('MOTORBIKE')).toBe('BIKE');
    expect(serviceForVehicleClass('CAR_4')).toBe('CAR');
  });
});

describe('PaymentMethodRegistryService', () => {
  it('defaults to cash-only with reasons on every other row', async () => {
    const { registry } = setup();
    const list = await registry.list('BIKE');
    expect(list.filter((m) => m.available).map((m) => m.code)).toEqual(['CASH']);
    expect(list.find((m) => m.code === 'MOMO')!.reason).toBe('Đang chờ cấp phép');
    expect(list.map((m) => m.group)).toContain('WALLET');
  });

  it('enables a REAL configured method per service only', async () => {
    const { registry } = setup();
    await enable(registry, 'MOMO', { BIKE: true, CAR: false, FOOD: false });
    expect((await registry.list('BIKE')).find((m) => m.code === 'MOMO')!.available).toBe(true);
    expect((await registry.list('CAR')).find((m) => m.code === 'MOMO')!.available).toBe(false);
    await expect(registry.assertSelectable('CAR', 'MOMO')).rejects.toMatchObject({ status: 422 });
    await expect(registry.assertSelectable('BIKE', 'MOMO')).resolves.toBe('MOMO');
  });

  it('never enables stubs, unconfigured providers, or the wallet without its flag', async () => {
    const { registry } = setup({ env: {} });
    for (const code of ['SHOPEEPAY', 'INTERNATIONAL_CARD', 'APPLE_PAY', 'MOMO', 'DEALGO_WALLET']) {
      await enable(registry, code);
    }
    const list = await registry.list('FOOD');
    expect(list.filter((m) => m.available).map((m) => m.code)).toEqual(['CASH']);
    const ops = await registry.listForOps();
    const momo = ops.methods.find((m) => m.code === 'MOMO')!;
    expect(momo.configured).toBe(false);
    expect(momo.requiredEnv).toContain('MOMO_SECRET_KEY');
    expect(JSON.stringify(ops)).not.toContain('"sk"');
    expect(ops.methods.find((m) => m.code === 'SHOPEEPAY')!.adapterKind).toBe('STUB');
    await registry.update({ walletEnabled: true }, 'wallet', 'ops-1');
    expect((await registry.list('FOOD')).find((m) => m.code === 'DEALGO_WALLET')!.available).toBe(false);
  });

  it('online methods need a public base URL for callbacks', async () => {
    const { registry } = setup({ publicBaseUrl: null });
    await enable(registry, 'MOMO');
    expect((await registry.list('BIKE')).find((m) => m.code === 'MOMO')!.available).toBe(false);
  });

  it('keeps order + reason edits', async () => {
    const { registry, settings } = setup();
    await registry.update({ methods: [{ code: 'ZALOPAY', sortOrder: 1, unsupportedReason: 'Tạm ẩn' }] }, 'order', 'ops-1');
    const list = await registry.list('BIKE');
    expect(list[0]!.code).toBe('ZALOPAY');
    expect(list[0]!.reason).toBe('Tạm ẩn');
    expect(settings.patches[0]!.reason).toBe('order');
  });
});

describe('PaymentGatewayService', () => {
  it('cash just records the choice', async () => {
    const { gateway } = setup();
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'CASH', amountVnd: 0, userId: 'u' });
    expect(v.status).toBe('CASH');
    expect((await gateway.status('RIDE', RIDE)).methodCode).toBe('CASH');
  });

  it('refuses disabled methods server-side', async () => {
    const { gateway } = setup();
    await expect(
      gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' }),
    ).rejects.toMatchObject({ status: 422 });
  });

  it('full lifecycle: pending → signed IPN captured (+ledger) → idempotent replay → refund', async () => {
    const { gateway, registry, ledger, repo } = setup();
    await enable(registry, 'MOMO');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    expect(v).toMatchObject({ status: 'PENDING', paymentUrl: 'https://momo/pay', deeplink: 'momo://pay', amountVnd: 50000 });
    const again = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    expect(again.intentId).toBe(v.intentId);
    const intent = (await repo.findById(v.intentId!))!;

    expect((await gateway.handleCallback('momo', { ...momoIpn(intent.providerRef!, 50000), signature: 'bad' })).httpStatus).toBe(400);
    expect((await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 1))).httpStatus).toBe(204);
    expect((await gateway.status('RIDE', RIDE)).status).toBe('PENDING');

    const ack = await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    expect(ack.httpStatus).toBe(204);
    expect((await gateway.status('RIDE', RIDE)).status).toBe('PAID');
    const journal = await ledger.getJournal('RIDE', RIDE).catch(() => null);
    expect(journal).toBeNull(); // getJournal reads COD_OBLIGATION_POSTED; capture is its own event
    const replay = await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    expect(replay.httpStatus).toBe(204);

    // Paid jobs cannot be switched or re-charged.
    const switched = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'CASH', amountVnd: 0, userId: 'u' });
    expect(switched.status).toBe('PAID');

    const refund = await gateway.refund({ intentId: intent.id, reason: 'Khach huy', actorUserId: 'ops' });
    expect(refund).toMatchObject({ status: 'REFUNDED', refundedVnd: 50000 });
    await expect(gateway.refund({ intentId: intent.id, reason: 'again', actorUserId: 'ops' })).rejects.toMatchObject({ status: 409 });
  });

  it('posts PSP capture and refund journals once', async () => {
    const { gateway, registry, repo, ledgerRepo } = setup();
    await enable(registry, 'MOMO');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const intent = (await repo.findById(v.intentId!))!;
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    const cap = await ledgerRepo.findByEntity('RIDE', RIDE, 'PSP_PAYMENT_CAPTURED');
    expect(cap?.amountVnd).toBe(50000);
    await gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'partial', actorUserId: 'ops' });
    expect((await ledgerRepo.findByEntity('RIDE', RIDE, 'PSP_REFUND_RECORDED'))?.amountVnd).toBe(20000);
  });

  it('failed IPN marks FAILED and the customer can retry', async () => {
    const { gateway, registry, repo } = setup();
    await enable(registry, 'MOMO');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const intent = (await repo.findById(v.intentId!))!;
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000, 1006));
    expect((await gateway.status('RIDE', RIDE)).status).toBe('FAILED');
    const retry = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    expect(retry.status).toBe('PENDING');
    expect((await repo.findById(retry.intentId!))!.providerRef).not.toBe(intent.providerRef);
  });

  it('ZaloPay callback captures via key2 MAC', async () => {
    const { gateway, registry, repo } = setup();
    await enable(registry, 'ZALOPAY');
    const v = await gateway.start({ entityType: 'FOOD_ORDER', entityId: RIDE, service: 'FOOD', methodCode: 'ZALOPAY', amountVnd: 120000, userId: 'u' });
    const intent = (await repo.findById(v.intentId!))!;
    const data = JSON.stringify({ app_trans_id: intent.providerRef, zp_trans_id: 5, amount: 120000 });
    const ack = await gateway.handleCallback('zalopay', { data, mac: createHmac('sha256', 'k2').update(data).digest('hex'), type: 1 });
    expect(ack.body).toEqual({ return_code: 1, return_message: 'success' });
    expect((await gateway.status('FOOD_ORDER', RIDE)).status).toBe('PAID');
  });

  it('VNPay ATM returns a signed redirect URL and unknown order acks 01', async () => {
    const { gateway, registry } = setup();
    await enable(registry, 'VNPAY_ATM');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'CAR', methodCode: 'VNPAY_ATM', amountVnd: 80000, userId: 'u', clientIp: '9.9.9.9' });
    expect(v.paymentUrl).toContain('vnp_BankCode=VNBANK');
    expect(v.paymentUrl).toContain('vnp_IpAddr=9.9.9.9');
    expect((await gateway.handleCallback('vnpay', { vnp_TxnRef: 'nope', vnp_SecureHash: 'x' })).body).toMatchObject({ RspCode: '97' });
  });

  it('provider errors surface as 502 without breaking cash', async () => {
    const { gateway, registry } = setup({ http: async () => ({ resultCode: 99, message: 'down' }) });
    await enable(registry, 'MOMO');
    await expect(
      gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' }),
    ).rejects.toMatchObject({ status: 502 });
    expect((await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'CASH', amountVnd: 0, userId: 'u' })).status).toBe('CASH');
  });

  it('online needs a final amount; stale pending expires', async () => {
    const { gateway, registry } = setup();
    await enable(registry, 'MOMO');
    await expect(
      gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 0, userId: 'u' }),
    ).rejects.toMatchObject({ status: 409 });
    const old = new Date(Date.now() - 20 * 60 * 1000);
    expect(toCheckoutStatus({ status: 'PENDING_REDIRECT', updatedAt: old } as never)).toBe('EXPIRED');
  });

  it('return redirect bounces to the app deeplink with status', async () => {
    const { gateway } = setup();
    const r = await gateway.returnRedirect('RIDE', RIDE);
    expect(r.url).toBe(`dealgo://payment-return?entityType=RIDE&entityId=${RIDE}&status=CASH`);
  });
});
