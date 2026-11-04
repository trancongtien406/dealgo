import { HttpException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import { describe, expect, it } from 'vitest';
import type { AppEnv } from '../../platform/config/env.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { PayosAdapter, payosSignature } from '../../integrations/payment-gateways/providers/index.js';
import type { EarningsService } from '../earnings/earnings.service.js';
import type { DriverBalance } from '../earnings/driver-balance.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import {
  MemoryDriverCreditRepository,
  type DriverTopUpProviderName,
  type DriverTopUpRecord,
} from './driver-credit.repository.js';
import { DriverCreditService, type DriverTopUpAdapters } from './driver-credit.service.js';
import { DriverCreditStatusBus } from './driver-credit-status.bus.js';

const CHECKSUM_KEY = 'checksum_test';
const NOW = new Date('2026-11-03T07:00:00.000Z');

type Limits = {
  enabled: boolean;
  minVnd: number;
  maxVnd: number;
  dailyLimitVnd: number;
  maxCreditVnd: number;
  expireMinutes: number;
};

function harness(overrides: Partial<Limits> = {}) {
  const limits: Limits = {
    enabled: true,
    minVnd: 10_000,
    maxVnd: 2_000_000,
    dailyLimitVnd: 5_000_000,
    maxCreditVnd: 5_000_000,
    expireMinutes: 15,
    ...overrides,
  };
  const repo = new MemoryDriverCreditRepository();
  const settings = {
    getBoolean: async (key: string) => (key === 'DRIVER_TOP_UP_ENABLED' ? limits.enabled : false),
    getNumber: async (key: string) =>
      ({
        DRIVER_TOP_UP_MIN_VND: limits.minVnd,
        DRIVER_TOP_UP_MAX_VND: limits.maxVnd,
        DRIVER_TOP_UP_DAILY_LIMIT_VND: limits.dailyLimitVnd,
        DRIVER_CREDIT_MAX_VND: limits.maxCreditVnd,
        DRIVER_TOP_UP_EXPIRE_MINUTES: limits.expireMinutes,
        DRIVER_DEBT_LIMIT_VND: 200_000,
      })[key] ?? 0,
  } as unknown as PlatformSettingsService;

  const earnings = {
    balanceOf: async (driverId: string): Promise<DriverBalance> => {
      const rows = (await repo.listByDriver(driverId, 100)).filter((row) => row.remainingVnd > 0);
      const creditVnd = rows.reduce((sum, row) => sum + row.remainingVnd, 0);
      return { feesVnd: 0, adjustmentsVnd: 0, amountVnd: 0, creditVnd, settledThrough: null };
    },
  } as unknown as EarningsService;

  const identity = {
    listGrants: async () => [{ role: 'DRIVER', status: 'ACTIVE' }],
  } as unknown as IdentityRepository;

  const adapters: DriverTopUpAdapters = {
    payos: new PayosAdapter(
      { clientId: 'client_test', apiKey: 'api_test', checksumKey: CHECKSUM_KEY },
      async () => ({
        code: '00',
        data: { checkoutUrl: 'https://pay.payos.vn/web/abc', qrCode: 'qr-data' },
      }),
    ),
  };

  const config = {
    get: (key: string) => (key === 'PAYMENT_PUBLIC_BASE_URL' ? 'https://api.test/' : undefined),
  } as unknown as ConfigService<AppEnv, true>;

  const bus = new DriverCreditStatusBus();
  const service = new DriverCreditService(
    repo,
    adapters,
    'payos' satisfies DriverTopUpProviderName,
    settings,
    earnings,
    identity,
    bus,
    config,
  );
  return { service, repo, limits, bus };
}

function signedCallback(row: DriverTopUpRecord, overrides: Record<string, unknown> = {}) {
  const data: Record<string, unknown> = {
    orderCode: row.orderCode,
    amount: row.amountVnd,
    code: '00',
    desc: 'Thanh cong',
    reference: 'TF-1',
    transactionDateTime: '2026-11-03T14:00:00+07:00',
    ...overrides,
  };
  return {
    code: '00',
    desc: 'success',
    success: true,
    data,
    signature: payosSignature(data, CHECKSUM_KEY),
  };
}

async function rejection(promise: Promise<unknown>): Promise<{ status: number; errorCode: string }> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof HttpException) {
      const body = error.getResponse() as { errorCode?: string };
      return { status: error.getStatus(), errorCode: body.errorCode ?? '' };
    }
    throw error;
  }
  throw new Error('expected the call to be rejected');
}

describe('DriverCreditService top-up lifecycle', () => {
  it('is unavailable until Ops enables the feature', async () => {
    const { service } = harness({ enabled: false });
    expect(await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 50_000 }))).toEqual({
      status: 403,
      errorCode: 'DRIVER_TOP_UP_DISABLED',
    });
  });

  it('rejects amounts outside the configured band', async () => {
    const { service } = harness();
    expect((await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 5_000 }))).errorCode).toBe(
      'DRIVER_TOP_UP_AMOUNT_INVALID',
    );
    expect(
      (await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 2_000_001 }))).errorCode,
    ).toBe('DRIVER_TOP_UP_AMOUNT_INVALID');
  });

  it('requires an approved KYC before taking money', async () => {
    const { service, repo } = harness();
    repo.isKycApproved = async () => false;
    expect((await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 50_000 }))).errorCode).toBe(
      'DRIVER_KYC_REQUIRED',
    );
  });

  it('requires an active driver role', async () => {
    const { service } = harness();
    const customerOnly = new DriverCreditService(
      new MemoryDriverCreditRepository(),
      {},
      'payos',
      { getBoolean: async () => true, getNumber: async (key: string) => (key === 'DRIVER_TOP_UP_MAX_VND' ? 2_000_000 : 10_000) } as unknown as PlatformSettingsService,
      {
        balanceOf: async (): Promise<DriverBalance> => ({
          feesVnd: 0,
          adjustmentsVnd: 0,
          amountVnd: 0,
          creditVnd: 0,
          settledThrough: null,
        }),
      } as unknown as EarningsService,
      { listGrants: async () => [{ role: 'CUSTOMER', status: 'ACTIVE' }] } as unknown as IdentityRepository,
      new DriverCreditStatusBus(),
      { get: () => 'https://api.test' } as unknown as ConfigService<AppEnv, true>,
    );
    expect((await rejection(customerOnly.createTopUp({ driverId: 'c1', amountVnd: 50_000 }))).errorCode).toBe(
      'ROLE_NOT_ACTIVE',
    );
    expect(customerOnly).toBeDefined();
    expect(service).toBeDefined();
  });

  it('creates a link, exposes the pending top-up and blocks a second one', async () => {
    const { service } = harness();
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    expect(created.status).toBe('PENDING');
    expect(created.checkoutUrl).toBe('https://pay.payos.vn/web/abc');
    expect(created.qrCode).toBe('qr-data');
    expect(created.expiresAt).not.toBeNull();

    const summary = await service.summary('d1');
    expect(summary.pendingTopUp?.id).toBe(created.id);
    expect(summary.creditVnd).toBe(0);

    expect(
      (await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 100_000 }))).errorCode,
    ).toBe('DRIVER_TOP_UP_PENDING');
  });

  it('replays the same order for a repeated idempotency key', async () => {
    const { service } = harness();
    const first = await service.createTopUp({
      driverId: 'd1',
      amountVnd: 100_000,
      idempotencyKey: 'key-1',
    });
    const second = await service.createTopUp({
      driverId: 'd1',
      amountVnd: 100_000,
      idempotencyKey: 'key-1',
    });
    expect(second.id).toBe(first.id);
  });

  it('enforces the daily paid total', async () => {
    const { service, repo } = harness();
    const row = await repo.create({
      driverId: 'd1',
      provider: 'payos',
      amountVnd: 4_990_000,
      idempotencyKey: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    await repo.attachLink(row.id, {
      providerRef: String(row.orderCode),
      paymentLinkId: null,
      checkoutUrl: null,
      qrCode: null,
    });
    await repo.capture({
      provider: 'payos',
      providerRef: String(row.orderCode),
      amountVnd: row.amountVnd,
      providerTransId: 'T0',
      paidAt: new Date(),
    });
    expect(
      (await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 100_000 }))).errorCode,
    ).toBe('DRIVER_TOP_UP_DAILY_LIMIT');
  });

  it('enforces the outstanding credit cap', async () => {
    const { service, repo } = harness({ maxCreditVnd: 120_000 });
    const row = await repo.create({
      driverId: 'd1',
      provider: 'payos',
      amountVnd: 100_000,
      idempotencyKey: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    await repo.attachLink(row.id, {
      providerRef: String(row.orderCode),
      paymentLinkId: null,
      checkoutUrl: null,
      qrCode: null,
    });
    await repo.capture({
      provider: 'payos',
      providerRef: String(row.orderCode),
      amountVnd: row.amountVnd,
      providerTransId: 'T0',
      paidAt: new Date(),
    });
    expect(
      (await rejection(service.createTopUp({ driverId: 'd1', amountVnd: 50_000 }))).errorCode,
    ).toBe('DRIVER_CREDIT_LIMIT');
  });

  it('credits the driver only on a signature-verified callback of the exact amount', async () => {
    const { service, repo } = harness();
    await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    const row = (await repo.findPending('d1'))!;

    const forged = await service.handleProviderCallback('payos', {
      ...signedCallback(row),
      signature: 'deadbeef',
    });
    expect(forged.body).toMatchObject({ code: '01', desc: 'INVALID_SIGNATURE' });
    expect((await service.summary('d1')).creditVnd).toBe(0);

    const mismatch = await service.handleProviderCallback(
      'payos',
      signedCallback({ ...row, amountVnd: 1 } as DriverTopUpRecord),
    );
    expect(mismatch.body).toMatchObject({ desc: 'AMOUNT_MISMATCH' });
    expect((await service.summary('d1')).creditVnd).toBe(0);

    const ok = await service.handleProviderCallback('payos', signedCallback(row));
    expect(ok.body).toMatchObject({ code: '00' });
    const summary = await service.summary('d1');
    expect(summary.creditVnd).toBe(100_000);
    expect(summary.pendingTopUp).toBeNull();
    expect(summary.recentTopUps[0]?.status).toBe('PAID');

    const replay = await service.handleProviderCallback('payos', signedCallback(row));
    expect(replay.body).toMatchObject({ code: '00' });
    expect((await service.summary('d1')).creditVnd).toBe(100_000);
  });

  it('emits a realtime hint only when money actually moves', async () => {
    const { service, repo, bus } = harness();
    const seen: string[] = [];
    bus.onChange((change) => {
      seen.push(`${change.status}:${change.topUpId}`);
    });
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    const row = (await repo.findPending('d1'))!;

    await service.handleProviderCallback('payos', { ...signedCallback(row), signature: 'deadbeef' });
    expect(seen).toEqual([]);

    await service.handleProviderCallback('payos', signedCallback(row));
    expect(seen).toEqual([`PAID:${created.id}`]);

    await service.refundTopUp({
      actorUserId: 'ops',
      topUpId: created.id,
      reason: 'Cham dut hop dong',
      bankRef: 'VCB-1',
    });
    expect(seen).toEqual([`PAID:${created.id}`, `REFUNDED:${created.id}`]);
  });

  it('serves the ops board detail, summary and driver identity', async () => {
    const { service } = harness();
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });

    const detail = await service.opsDetail(created.id);
    expect(detail).toMatchObject({
      id: created.id,
      driverId: 'd1',
      driverName: null,
      amountVnd: 100_000,
      orderCode: created.orderCode,
      provider: 'payos',
    });

    const summary = await service.opsSummary(new Date('2026-11-03T03:00:00.000Z'));
    expect(summary.pendingCount).toBe(1);
    expect(summary.pendingVnd).toBe(100_000);
    expect(summary.outstandingCreditVnd).toBe(0);

    expect((await rejection(service.opsDetail('missing'))).errorCode).toBe('DRIVER_TOP_UP_NOT_FOUND');
  });

  it('cancels a pending top-up and refuses to cancel afterwards', async () => {
    const { service } = harness();
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    const cancelled = await service.cancelTopUp('d1', created.id);
    expect(cancelled.status).toBe('CANCELLED');
    expect((await rejection(service.cancelTopUp('d1', created.id))).errorCode).toBe(
      'DRIVER_TOP_UP_NOT_PENDING',
    );
  });

  it('hides another driver top-up', async () => {
    const { service } = harness();
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    expect((await rejection(service.topUp('d2', created.id))).errorCode).toBe(
      'DRIVER_TOP_UP_NOT_FOUND',
    );
  });

  it('refunds only unused credit with an audit reason and bank reference', async () => {
    const { service, repo } = harness();
    const created = await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    expect(
      (await rejection(
        service.refundTopUp({ actorUserId: 'ops', topUpId: created.id, reason: 'no', bankRef: 'x' }),
      )).errorCode,
    ).toBe('DRIVER_CREDIT_REFUND_REASON_REQUIRED');

    const row = (await repo.findPending('d1'))!;
    await service.handleProviderCallback('payos', signedCallback(row));

    const refunded = await service.refundTopUp({
      actorUserId: 'ops',
      topUpId: created.id,
      reason: 'Cham dut hop dong',
      bankRef: 'VCB-99881',
    });
    expect(refunded.status).toBe('REFUNDED');
    expect(refunded.remainingVnd).toBe(0);
    expect((await service.summary('d1')).creditVnd).toBe(0);
  });

  it('acknowledges a failure callback without crediting the driver', async () => {
    const { service, repo } = harness();
    await service.createTopUp({ driverId: 'd1', amountVnd: 100_000 });
    const row = (await repo.findPending('d1'))!;
    const data = { orderCode: row.orderCode, amount: row.amountVnd, code: '01', desc: 'Huy', reference: 'T1' };
    const ack = await service.handleProviderCallback('payos', {
      code: '01',
      desc: 'failed',
      success: false,
      data,
      signature: payosSignature(data, CHECKSUM_KEY),
    });
    expect(ack.body).toMatchObject({ code: '00' });
    expect((await service.summary('d1')).creditVnd).toBe(0);
    expect((await repo.findById(row.id))?.status).toBe('FAILED');
  });

  it('routes only payOS and DGCT-prefixed VNPAY traffic to driver credit', () => {
    const { service } = harness();
    expect(service.isDriverTopUpCallback('payos', {})).toBe(true);
    expect(service.isDriverTopUpCallback('vnpay', { vnp_TxnRef: 'DGCT1000000001' })).toBe(true);
    expect(service.isDriverTopUpCallback('vnpay', { vnp_TxnRef: 'DGRABC' })).toBe(false);
    expect(service.isDriverTopUpCallback('momo', {})).toBe(false);
  });
});

describe('DriverCreditService.reconcilePending', () => {
  it('captures a paid link whose callback was missed, and expires the rest', async () => {
    const now = new Date(Date.now() + 120_000);
    const repo = new MemoryDriverCreditRepository();
    const paid = await repo.create({
      driverId: 'd1',
      provider: 'payos',
      amountVnd: 100_000,
      idempotencyKey: null,
      expiresAt: new Date(now.getTime() + 600_000),
    });
    await repo.attachLink(paid.id, {
      providerRef: String(paid.orderCode),
      paymentLinkId: null,
      checkoutUrl: null,
      qrCode: null,
    });
    const abandoned = await repo.create({
      driverId: 'd2',
      provider: 'payos',
      amountVnd: 50_000,
      idempotencyKey: null,
      expiresAt: new Date(now.getTime() - 1_000),
    });
    await repo.attachLink(abandoned.id, {
      providerRef: String(abandoned.orderCode),
      paymentLinkId: null,
      checkoutUrl: null,
      qrCode: null,
    });

    const queried: string[] = [];
    const adapter = new PayosAdapter(
      { clientId: 'c', apiKey: 'a', checksumKey: CHECKSUM_KEY },
      async (method, url) => {
        queried.push(`${method} ${url}`);
        const ref = String(paid.orderCode);
        if (url.includes(ref)) {
          return {
            code: '00',
            data: {
              id: 'link-1',
              orderCode: paid.orderCode,
              amount: paid.amountVnd,
              amountPaid: paid.amountVnd,
              amountRemaining: 0,
              status: 'PAID',
              transactions: [{ reference: 'TF-9', amount: paid.amountVnd }],
            },
          };
        }
        return {
          code: '00',
          data: {
            id: 'link-2',
            orderCode: abandoned.orderCode,
            amount: abandoned.amountVnd,
            amountPaid: 0,
            amountRemaining: abandoned.amountVnd,
            status: 'PENDING',
            transactions: [],
          },
        };
      },
    );

    const service = new DriverCreditService(
      repo,
      { payos: adapter },
      'payos',
      { getNumber: async () => 200_000 } as unknown as PlatformSettingsService,
      {} as EarningsService,
      {} as IdentityRepository,
      new DriverCreditStatusBus(),
      { get: () => 'https://api.test' } as unknown as ConfigService<AppEnv, true>,
    );

    const result = await service.reconcilePending(now);
    expect(result.checked).toBe(2);
    expect(result.captured).toBe(1);
    expect(result.closed).toBe(1);
    expect(queried).toHaveLength(2);
    expect((await repo.findById(paid.id))?.status).toBe('PAID');
    expect((await repo.findById(abandoned.id))?.status).toBe('EXPIRED');
  });
});

describe('MemoryDriverCreditRepository', () => {
  it('counts only top-ups paid since the window start', async () => {
    const repo = new MemoryDriverCreditRepository();
    const old = await repo.create({
      driverId: 'd1',
      provider: 'payos',
      amountVnd: 30_000,
      idempotencyKey: null,
      expiresAt: NOW,
    });
    await repo.attachLink(old.id, {
      providerRef: String(old.orderCode),
      paymentLinkId: null,
      checkoutUrl: null,
      qrCode: null,
    });
    await repo.capture({
      provider: 'payos',
      providerRef: String(old.orderCode),
      amountVnd: 30_000,
      providerTransId: null,
      paidAt: new Date(NOW.getTime() - 48 * 3_600_000),
    });
    expect(await repo.sumPaidSince('d1', new Date(NOW.getTime() - 24 * 3_600_000))).toBe(0);
    expect(await repo.sumPaidSince('d1', new Date(NOW.getTime() - 72 * 3_600_000))).toBe(30_000);
  });
});
