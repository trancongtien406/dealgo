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
import {
  LATE_CAPTURE_AFTER_CASH,
  PaymentGatewayService,
  SUPERSEDED_BY_CASH,
  attemptTimeFromRef,
  splitCollection,
  toCheckoutStatus,
} from './payment-gateway.service.js';
import { PaymentStatusBus, type PaymentStatusChange } from './payment-status-bus.js';
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
  const bus = new PaymentStatusBus();
  const gateway = new PaymentGatewayService(repo, adapters, options, registry, ledger, bus);
  return { bus, settings, registry, repo, ledger, ledgerRepo, gateway, calls };
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
    expect(n.methods.CASH!.services).toEqual({ BIKE: true, CAR: true, FOOD: true, PARCEL: true });
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
    const cap = await ledgerRepo.findByEntity('PAYMENT_INTENT', intent.id, 'PSP_PAYMENT_CAPTURED');
    expect(cap?.amountVnd).toBe(50000);
    const r = await gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'partial', actorUserId: 'ops' });
    expect((await ledgerRepo.findByEntity('PAYMENT_REFUND', r.refund.id, 'PSP_REFUND_RECORDED'))?.amountVnd).toBe(20000);
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

async function capturedMomo(ctx: ReturnType<typeof setup>, amount = 50000, entityId = RIDE) {
  await enable(ctx.registry, 'MOMO');
  const v = await ctx.gateway.start({ entityType: 'RIDE', entityId, service: 'BIKE', methodCode: 'MOMO', amountVnd: amount, userId: 'u' });
  const intent = (await ctx.repo.findById(v.intentId!))!;
  await ctx.gateway.handleCallback('momo', momoIpn(intent.providerRef!, amount));
  return intent;
}

describe('online vs cash settlement', () => {
  it('splits the job amount into online and cash', () => {
    expect(splitCollection(50000, 50000)).toEqual({ onlineVnd: 50000, cashVnd: 0 });
    expect(splitCollection(50000, 0)).toEqual({ onlineVnd: 0, cashVnd: 50000 });
    expect(splitCollection(50000, 30000)).toEqual({ onlineVnd: 30000, cashVnd: 20000 });
    expect(splitCollection(40000, 60000)).toEqual({ onlineVnd: 40000, cashVnd: 0 });
    expect(splitCollection(0, 10000)).toEqual({ onlineVnd: 0, cashVnd: 0 });
  });

  it('driver collection: paid online → nothing to collect; cash → full amount', async () => {
    const ctx = setup();
    expect(await ctx.gateway.collection('RIDE', RIDE, 50000)).toMatchObject({ status: 'CASH', paidOnlineVnd: 0, cashToCollectVnd: 50000 });
    await capturedMomo(ctx);
    expect(await ctx.gateway.collection('RIDE', RIDE, 50000)).toMatchObject({ status: 'PAID', paidOnlineVnd: 50000, cashToCollectVnd: 0 });
  });

  it('prepaid is reduced by refunds and consumed once at completion', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx);
    expect(await ctx.gateway.prepaidFor('RIDE', RIDE)).toEqual({ intentId: intent.id, amountVnd: 50000 });
    await ctx.gateway.refund({ intentId: intent.id, amountVnd: 10000, reason: 'partial', actorUserId: 'ops' });
    expect((await ctx.gateway.prepaidFor('RIDE', RIDE))!.amountVnd).toBe(40000);
    await ctx.gateway.afterCompletion('RIDE', RIDE, intent.id);
    expect(await ctx.gateway.prepaidFor('RIDE', RIDE)).toBeNull();
    // Refund after the driver was credited: DealGo absorbs it as an expense.
    const r = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 5000, reason: 'goodwill', actorUserId: 'ops' });
    expect(r.refund.afterSettlement).toBe(true);
    expect((await ctx.ledgerRepo.findByEntity('PAYMENT_REFUND', r.refund.id, 'PSP_REFUND_AFTER_SETTLEMENT'))?.amountVnd).toBe(5000);
  });

  it('cash completion retires a pending attempt; a late capture is flagged for refund', async () => {
    const ctx = setup();
    await enable(ctx.registry, 'MOMO');
    const v = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const pending = (await ctx.repo.findById(v.intentId!))!;
    expect(await ctx.gateway.prepaidFor('RIDE', RIDE)).toBeNull();
    await ctx.gateway.afterCompletion('RIDE', RIDE, null);
    expect(await ctx.repo.findById(pending.id)).toMatchObject({ status: 'EXPIRED', failureReason: SUPERSEDED_BY_CASH });
    await ctx.gateway.handleCallback('momo', momoIpn(pending.providerRef!, 50000));
    const late = (await ctx.repo.findById(pending.id))!;
    expect(late).toMatchObject({ status: 'CAPTURED', failureReason: LATE_CAPTURE_AFTER_CASH, settledAt: null });
    expect((await ctx.gateway.collection('RIDE', RIDE, 50000)).paidOnlineVnd).toBe(0);
  });
});

describe('capture safety (MONEY-002 / MONEY-003)', () => {
  it('a second online payment for the same job (other method) gets its own capture journal', async () => {
    const ctx = setup();
    await enable(ctx.registry, 'MOMO');
    await enable(ctx.registry, 'ZALOPAY');
    const zalo = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'ZALOPAY', amountVnd: 50000, userId: 'u' });
    const momo = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const zi = (await ctx.repo.findById(zalo.intentId!))!;
    const mi = (await ctx.repo.findById(momo.intentId!))!;
    // Customer paid in both apps (two open redirects): both captures must be on the books.
    await ctx.gateway.handleCallback('momo', momoIpn(mi.providerRef!, 50000));
    const data = JSON.stringify({ app_trans_id: zi.providerRef, zp_trans_id: 5, amount: 50000 });
    await ctx.gateway.handleCallback('zalopay', { data, mac: createHmac('sha256', 'k2').update(data).digest('hex'), type: 1 });
    expect((await ctx.ledgerRepo.findByEntity('PAYMENT_INTENT', mi.id, 'PSP_PAYMENT_CAPTURED'))?.amountVnd).toBe(50000);
    expect((await ctx.ledgerRepo.findByEntity('PAYMENT_INTENT', zi.id, 'PSP_PAYMENT_CAPTURED'))?.amountVnd).toBe(50000);
  });

  it('concurrent IPNs (different event ids) capture and journal once', async () => {
    const ctx = setup();
    await enable(ctx.registry, 'MOMO');
    const v = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const intent = (await ctx.repo.findById(v.intentId!))!;
    let posts = 0;
    const orig = ctx.ledger.postEvent.bind(ctx.ledger);
    ctx.ledger.postEvent = (async (...args: Parameters<typeof orig>) => {
      posts += 1;
      return orig(...args);
    }) as typeof orig;
    await Promise.all([
      ctx.gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000, 0, 1)),
      ctx.gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000, 0, 2)),
    ]);
    expect(posts).toBe(1);
    expect((await ctx.repo.findById(intent.id))!.status).toBe('CAPTURED');
  });

  it('a failure IPN never overwrites a captured intent', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx);
    await ctx.repo.transition(intent.id, ['CREATED', 'PENDING_REDIRECT'], { status: 'FAILED' });
    expect((await ctx.repo.findById(intent.id))!.status).toBe('CAPTURED');
  });

  it('a later failed attempt on another method cannot reopen a paid job', async () => {
    const ctx = setup();
    const paid = await capturedMomo(ctx);
    await enable(ctx.registry, 'ZALOPAY');
    const z = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'ZALOPAY', amountVnd: 50000, userId: 'u' });
    expect(z).toMatchObject({ status: 'PAID', intentId: paid.id });
  });
});

describe('auto refund on cancel (FOOD-002)', () => {
  it('refunds the remaining prepayment in full exactly once, skipping settled jobs', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx, 80000);
    await ctx.gateway.refund({ intentId: intent.id, amountVnd: 10000, reason: 'partial', actorUserId: 'ops' });
    const first = await ctx.gateway.refundOnCancel('RIDE', RIDE, 'u');
    expect(first).toHaveLength(1);
    expect((await ctx.repo.findById(intent.id))).toMatchObject({ status: 'REFUNDED', refundedVnd: 80000 });
    // Outbox replay: same key → no second refund row.
    const again = await ctx.gateway.refundOnCancel('RIDE', RIDE, 'u');
    expect(again[0]).toMatchObject({ refundId: first[0]!.refundId, replayed: true });
    expect((await ctx.gateway.intentDetail(intent.id)).refunds).toHaveLength(2);

    const other = setup();
    const settled = await capturedMomo(other, 50000);
    await other.gateway.afterCompletion('RIDE', RIDE, settled.id);
    expect(await other.gateway.refundOnCancel('RIDE', RIDE, 'u')).toEqual([]);
    expect(await setup().gateway.refundOnCancel('RIDE', RIDE, 'u')).toEqual([]);
  });
});

describe('refund idempotency (ADM-003)', () => {
  it('the same key replays the first refund instead of refunding twice', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx, 100000);
    const a = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 30000, reason: 'one', actorUserId: 'ops', idempotencyKey: 'key-aaaaaaaa' });
    const b = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 30000, reason: 'one', actorUserId: 'ops', idempotencyKey: 'key-aaaaaaaa' });
    expect(b.refund.id).toBe(a.refund.id);
    expect(b.refundedVnd).toBe(30000);
    const detail = await ctx.gateway.intentDetail(intent.id);
    expect(detail.refunds).toHaveLength(1);
    const c = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 10000, reason: 'two', actorUserId: 'ops', idempotencyKey: 'key-bbbbbbbb' });
    expect(c.refundedVnd).toBe(40000);
  });

  it('concurrent submissions with one key refund once', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx, 100000);
    const [x, y] = await Promise.all([
      ctx.gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'dup', actorUserId: 'ops', idempotencyKey: 'key-cccccccc' }),
      ctx.gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'dup', actorUserId: 'ops', idempotencyKey: 'key-cccccccc' }),
    ]);
    expect(x.refund.id).toBe(y.refund.id);
    expect((await ctx.repo.findById(intent.id))!.refundedVnd).toBe(20000);
  });

  it('rejects a key reused for another payment', async () => {
    const ctx = setup();
    const a = await capturedMomo(ctx, 50000);
    await ctx.gateway.refund({ intentId: a.id, amountVnd: 1000, reason: 'one', actorUserId: 'ops', idempotencyKey: 'key-dddddddd' });
    const b = await capturedMomo(ctx, 50000, '22222222-2222-4222-8222-222222222222');
    await expect(
      ctx.gateway.refund({ intentId: b.id, amountVnd: 1000, reason: 'one', actorUserId: 'ops', idempotencyKey: 'key-dddddddd' }),
    ).rejects.toMatchObject({ status: 409 });
  });
});

describe('multiple partial refunds', () => {
  it('allows several refunds up to the captured amount, one journal each', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx, 100000);
    const a = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 30000, reason: 'one', actorUserId: 'ops' });
    expect(a).toMatchObject({ status: 'CAPTURED', refundedVnd: 30000, refundableVnd: 70000 });
    await expect(
      ctx.gateway.refund({ intentId: intent.id, amountVnd: 80000, reason: 'too much', actorUserId: 'ops' }),
    ).rejects.toMatchObject({ status: 400 });
    const b = await ctx.gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'two', actorUserId: 'ops' });
    expect(b.refundedVnd).toBe(50000);
    const c = await ctx.gateway.refund({ intentId: intent.id, reason: 'rest', actorUserId: 'ops' });
    expect(c).toMatchObject({ status: 'REFUNDED', refundedVnd: 100000, refundableVnd: 0 });
    await expect(ctx.gateway.refund({ intentId: intent.id, amountVnd: 1, reason: 'x', actorUserId: 'ops' })).rejects.toMatchObject({ status: 409 });
    const detail = await ctx.gateway.intentDetail(intent.id);
    expect(detail.refunds.map((r) => r.amountVnd)).toEqual([30000, 20000, 50000]);
    for (const r of detail.refunds) {
      expect(await ctx.ledgerRepo.findByEntity('PAYMENT_REFUND', r.id, 'PSP_REFUND_RECORDED')).not.toBeNull();
    }
  });

  it('a provider rejection releases the reserved amount', async () => {
    let refundCode = 0;
    const ctx = setup({
      http: async (url) => {
        if (url.endsWith('/refund')) return { resultCode: refundCode, message: 'no' };
        return { resultCode: 0, payUrl: 'https://momo/pay' };
      },
    });
    const intent = await capturedMomo(ctx, 50000);
    refundCode = 1001;
    await expect(ctx.gateway.refund({ intentId: intent.id, amountVnd: 20000, reason: 'r', actorUserId: 'ops' })).rejects.toMatchObject({ status: 502 });
    const after = await ctx.gateway.intentDetail(intent.id);
    expect(after).toMatchObject({ refundedVnd: 0, refundableVnd: 50000 });
    expect(after.refunds[0]!.status).toBe('REJECTED');
  });

  it('pending provider refund on the full amount sets REFUND_PENDING', async () => {
    const ctx = setup({
      http: async (url) => (url.endsWith('/refund') ? { resultCode: 7000 } : { resultCode: 0, payUrl: 'https://momo/pay' }),
    });
    const intent = await capturedMomo(ctx, 50000);
    const r = await ctx.gateway.refund({ intentId: intent.id, reason: 'full', actorUserId: 'ops' });
    expect(r.status).toBe('REFUND_PENDING');
    expect(r.refund.status).toBe('PENDING');
  });

  it('lists intents with provider/entity/q filters', async () => {
    const ctx = setup();
    const intent = await capturedMomo(ctx);
    expect(await ctx.gateway.listIntents(50, undefined, { provider: 'momo' })).toHaveLength(1);
    expect(await ctx.gateway.listIntents(50, undefined, { provider: 'vnpay' })).toHaveLength(0);
    expect(await ctx.gateway.listIntents(50, undefined, { entityType: 'FOOD_ORDER' })).toHaveLength(0);
    expect((await ctx.gateway.listIntents(50, undefined, { q: intent.providerRef! }))[0]!.id).toBe(intent.id);
  });
});

describe('active reconciliation', () => {
  const later = () => new Date(Date.now() + 5 * 60 * 1000);

  it('recovers a missed MoMo IPN via the query API exactly once', async () => {
    const queries: Record<string, unknown>[] = [];
    const ctx = setup({
      http: async (url, body) => {
        if (url.endsWith('/query')) {
          queries.push(body);
          return { resultCode: 0, amount: 50000, transId: 777, responseTime: 1 };
        }
        return { resultCode: 0, payUrl: 'https://momo/pay' };
      },
    });
    await enable(ctx.registry, 'MOMO');
    const v = await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const s1 = await ctx.gateway.reconcilePending(later());
    expect(s1).toMatchObject({ checked: 1, captured: 1 });
    const q = queries[0]!;
    const raw = `accessKey=ak&orderId=${String(q.orderId)}&partnerCode=MOMOTEST&requestId=${String(q.requestId)}`;
    expect(q.signature).toBe(createHmac('sha256', 'sk').update(raw).digest('hex'));
    expect(await ctx.repo.findById(v.intentId!)).toMatchObject({ status: 'CAPTURED', providerTransId: '777', reconcileAttempts: 1 });
    const s2 = await ctx.gateway.reconcilePending(later());
    expect(s2.checked).toBe(0);
    // A late real IPN is a no-op (already captured) and the capture journal stays single.
    const intent = (await ctx.repo.findById(v.intentId!))!;
    await ctx.gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000, 0, 777));
    expect((await ctx.ledgerRepo.findByEntity('PAYMENT_INTENT', intent.id, 'PSP_PAYMENT_CAPTURED'))?.amountVnd).toBe(50000);
  });

  it('marks ZaloPay failures and keeps polling pending ones; amount mismatch is not captured', async () => {
    let code = 3;
    let amount = 120000;
    const ctx = setup({
      http: async (url, body) => {
        if (url.endsWith('/v2/create')) return { return_code: 1, order_url: 'https://zalo/pay' };
        if (url.endsWith('/v2/query')) {
          expect(body.mac).toBe(createHmac('sha256', 'k1').update(`2553|${String(body.app_trans_id)}|k1`).digest('hex'));
          return { return_code: code, amount, zp_trans_id: 9 };
        }
        return {};
      },
    });
    await enable(ctx.registry, 'ZALOPAY');
    const v = await ctx.gateway.start({ entityType: 'FOOD_ORDER', entityId: RIDE, service: 'FOOD', methodCode: 'ZALOPAY', amountVnd: 120000, userId: 'u' });
    expect((await ctx.gateway.reconcilePending(later())).pending).toBe(1);
    code = 1;
    amount = 1;
    await ctx.gateway.reconcilePending(later());
    expect(await ctx.repo.findById(v.intentId!)).toMatchObject({ status: 'PENDING_REDIRECT', failureReason: 'RECONCILE_AMOUNT_MISMATCH' });
    code = 2;
    await ctx.gateway.reconcilePending(later());
    expect((await ctx.repo.findById(v.intentId!))!.status).toBe('FAILED');
  });

  it('VNPay querydr is signed in field order and uses the attempt time', async () => {
    let sent: Record<string, unknown> = {};
    const ctx = setup({
      http: async (_url, body) => {
        sent = body;
        return { vnp_ResponseCode: '00', vnp_TransactionStatus: '01' };
      },
    });
    await enable(ctx.registry, 'VNPAY');
    await ctx.gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'CAR', methodCode: 'VNPAY', amountVnd: 80000, userId: 'u' });
    expect((await ctx.gateway.reconcilePending(later())).pending).toBe(1);
    const f = sent as Record<string, string>;
    expect(f.vnp_Command).toBe('querydr');
    const input = [f.vnp_RequestId, f.vnp_Version, f.vnp_Command, f.vnp_TmnCode, f.vnp_TxnRef, f.vnp_TransactionDate, f.vnp_CreateDate, f.vnp_IpAddr, f.vnp_OrderInfo].join('|');
    expect(f.vnp_SecureHash).toBe(createHmac('sha512', 'hs').update(input).digest('hex'));
    expect(f.vnp_TransactionDate).toMatch(/^\d{14}$/);
  });

  it('skips unconfigured providers and recovers order-ref timestamps', async () => {
    const ref = `DGR${(1_800_000_000_000).toString(36).toUpperCase()}ABCDEF0123`;
    expect(attemptTimeFromRef(ref, new Date(0)).getTime()).toBe(1_800_000_000_000);
    expect(attemptTimeFromRef('garbage', new Date(5)).getTime()).toBe(5);
    const ctx = setup();
    expect(await ctx.gateway.reconcilePending(later())).toMatchObject({ checked: 0 });
  });
});

describe('payment status push (t50u, replaces the app poll)', () => {
  it('publishes PAID, refund and FAILED changes once per transition, never on replay or bad IPN', async () => {
    const { gateway, registry, repo, bus } = setup();
    const seen: PaymentStatusChange[] = [];
    bus.onChange((c) => {
      seen.push(c);
    });
    await enable(registry, 'MOMO');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const intent = (await repo.findById(v.intentId!))!;
    await gateway.handleCallback('momo', { ...momoIpn(intent.providerRef!, 50000), signature: 'bad' });
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 1));
    expect(seen).toHaveLength(0);
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000));
    expect(seen.map((c) => c.status)).toEqual(['PAID']);
    expect(seen[0]).toMatchObject({ entityType: 'RIDE', entityId: RIDE, intentId: intent.id });
    await gateway.refund({ intentId: intent.id, reason: 'Khach huy', actorUserId: 'ops' });
    expect(seen.map((c) => c.status)).toEqual(['PAID', 'REFUNDED']);
  });

  it('a throwing listener never breaks the IPN ack', async () => {
    const { gateway, registry, repo, bus } = setup();
    bus.onChange(() => {
      throw new Error('boom');
    });
    await enable(registry, 'MOMO');
    const v = await gateway.start({ entityType: 'RIDE', entityId: RIDE, service: 'BIKE', methodCode: 'MOMO', amountVnd: 50000, userId: 'u' });
    const intent = (await repo.findById(v.intentId!))!;
    expect((await gateway.handleCallback('momo', momoIpn(intent.providerRef!, 50000, 1006))).httpStatus).toBe(204);
    expect((await gateway.status('RIDE', RIDE)).status).toBe('FAILED');
  });

  it('unsubscribe stops delivery', () => {
    const bus = new PaymentStatusBus();
    const seen: string[] = [];
    const off = bus.onChange((c) => {
      seen.push(c.status);
    });
    const change = { entityType: 'FOOD_ORDER' as const, entityId: 'f', intentId: 'i', status: 'PAID' as const, occurredAt: 'now' };
    bus.publish(change);
    off();
    bus.publish(change);
    expect(seen).toEqual(['PAID']);
  });
});
