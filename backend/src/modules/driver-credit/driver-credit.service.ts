import { HttpException, Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  PaymentAdapterError,
  type CallbackAck,
  type PaymentAdapter,
} from '../../integrations/payment-gateways/providers/index.js';
import { EarningsService } from '../earnings/earnings.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import {
  DRIVER_CREDIT_REPOSITORY,
  DRIVER_TOP_UP_ADAPTERS,
  DRIVER_TOP_UP_PROVIDER,
  type DriverCreditRepository,
  type DriverTopUpProviderName,
  type DriverTopUpRecord,
  type DriverTopUpStatusName,
  type DriverTopUpSummary,
  type OpsDriverTopUpRecord,
} from './driver-credit.repository.js';
import { DriverCreditStatusBus } from './driver-credit-status.bus.js';

export type DriverTopUpAdapters = Partial<Record<DriverTopUpProviderName, PaymentAdapter>>;

export type DriverTopUpView = {
  id: string;
  amountVnd: number;
  remainingVnd: number;
  consumedVnd: number;
  refundedVnd: number;
  orderCode: number;
  provider: string;
  status: DriverTopUpRecord['status'];
  checkoutUrl: string | null;
  qrCode: string | null;
  expiresAt: string | null;
  paidAt: string | null;
  createdAt: string;
};

export type OpsDriverTopUpView = DriverTopUpView & {
  driverId: string;
  driverName: string | null;
  driverPhone: string | null;
  providerRef: string | null;
  providerTransId: string | null;
  failureReason: string | null;
  refundedAt: string | null;
  refundBankRef: string | null;
  refundReason: string | null;
};

export type DriverCreditView = {
  /** Unused prepayment available to offset fees. */
  creditVnd: number;
  /** Money the driver still owes DealGo after applying credit. */
  owesVnd: number;
  /** Limit above which new jobs are blocked. */
  limitVnd: number;
  blocked: boolean;
  enabled: boolean;
  minVnd: number;
  maxVnd: number;
  dailyLimitVnd: number;
  maxCreditVnd: number;
  pendingTopUp: DriverTopUpView | null;
  recentTopUps: DriverTopUpView[];
};

const MAX_TOP_UP = 50_000_000;
const DEFAULT_EXPIRE_MINUTES = 15;
const VN_OFFSET_MS = 7 * 3_600_000;

/**
 * Driver prepayments (DEC-PROD-093). Credit can only offset platform fees: no withdrawal,
 * no transfer, no third-party payment, no interest. Money is credited exclusively from a
 * signature-verified PSP callback for the exact amount of the pending order.
 */
@Injectable()
export class DriverCreditService {
  private readonly logger = new Logger(DriverCreditService.name);

  constructor(
    @Inject(DRIVER_CREDIT_REPOSITORY) private readonly repo: DriverCreditRepository,
    @Inject(DRIVER_TOP_UP_ADAPTERS) private readonly adapters: DriverTopUpAdapters,
    @Inject(DRIVER_TOP_UP_PROVIDER) private readonly provider: DriverTopUpProviderName,
    private readonly settings: PlatformSettingsService,
    private readonly earnings: EarningsService,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly bus: DriverCreditStatusBus,
    @Optional() private readonly config?: ConfigService<AppEnv, true>,
  ) {}

  async summary(driverId: string): Promise<DriverCreditView> {
    const [balance, cfg, pending, recent, limitVnd] = await Promise.all([
      this.earnings.balanceOf(driverId),
      this.limits(),
      this.repo.findPending(driverId),
      this.repo.listByDriver(driverId, 10),
      this.settings.getNumber('DRIVER_DEBT_LIMIT_VND'),
    ]);
    return {
      creditVnd: balance.creditVnd,
      owesVnd: Math.max(0, balance.amountVnd),
      limitVnd,
      blocked: limitVnd > 0 && balance.amountVnd > limitVnd,
      enabled: cfg.enabled,
      minVnd: cfg.minVnd,
      maxVnd: cfg.maxVnd,
      dailyLimitVnd: cfg.dailyLimitVnd,
      maxCreditVnd: cfg.maxCreditVnd,
      pendingTopUp: pending && this.isOpen(pending) ? toView(pending) : null,
      recentTopUps: recent.map(toView),
    };
  }

  async listTopUps(driverId: string, limit = 20): Promise<DriverTopUpView[]> {
    const rows = await this.repo.listByDriver(driverId, clampLimit(limit));
    return rows.map(toView);
  }

  async topUp(driverId: string, topUpId: string): Promise<DriverTopUpView> {
    const row = await this.repo.findById(topUpId);
    if (!row || row.driverId !== driverId) {
      fail(404, 'DRIVER_TOP_UP_NOT_FOUND', 'Top-up not found');
    }
    return toView(row);
  }

  async createTopUp(input: {
    driverId: string;
    amountVnd: number;
    idempotencyKey?: string | null;
  }): Promise<DriverTopUpView> {
    const cfg = await this.limits();
    if (!cfg.enabled) {
      fail(403, 'DRIVER_TOP_UP_DISABLED', 'Driver top-up is not available yet');
    }
    if (
      !Number.isSafeInteger(input.amountVnd) ||
      input.amountVnd < cfg.minVnd ||
      input.amountVnd > Math.min(cfg.maxVnd, MAX_TOP_UP)
    ) {
      fail(
        400,
        'DRIVER_TOP_UP_AMOUNT_INVALID',
        `Amount must be an integer between ${cfg.minVnd} and ${Math.min(cfg.maxVnd, MAX_TOP_UP)} VND`,
      );
    }
    await this.requireDriver(input.driverId);
    if (!(await this.repo.isKycApproved(input.driverId))) {
      fail(403, 'DRIVER_KYC_REQUIRED', 'An approved driver KYC is required before top-up');
    }

    const adapter = this.adapter();
    if (!adapter.isConfigured()) {
      fail(503, 'DRIVER_TOP_UP_PROVIDER_NOT_CONFIGURED', 'Payment provider is not configured');
    }
    const baseUrl = this.publicBaseUrl();
    if (!baseUrl) {
      fail(503, 'DRIVER_TOP_UP_UNAVAILABLE', 'Payment callback base URL is not configured');
    }

    const key = input.idempotencyKey?.trim() || null;
    if (key) {
      const existing = await this.repo.findByIdempotencyKey(input.driverId, key);
      if (existing && existing.driverId === input.driverId) {
        return toView(existing);
      }
    }

    const pending = await this.repo.findPending(input.driverId);
    if (pending && this.isOpen(pending)) {
      fail(409, 'DRIVER_TOP_UP_PENDING', 'A top-up is already waiting for payment');
    }
    if (pending) {
      await this.repo.close(pending.id, 'EXPIRED', 'Payment link expired');
    }

    const now = new Date();
    const dailyVnd = await this.repo.sumPaidSince(input.driverId, startOfVnDay(now));
    if (dailyVnd + input.amountVnd > cfg.dailyLimitVnd) {
      fail(400, 'DRIVER_TOP_UP_DAILY_LIMIT', 'Daily top-up limit reached');
    }
    const balance = await this.earnings.balanceOf(input.driverId);
    if (balance.creditVnd + input.amountVnd > cfg.maxCreditVnd) {
      fail(400, 'DRIVER_CREDIT_LIMIT', 'Prepaid balance limit reached');
    }

    const expiresAt = new Date(now.getTime() + cfg.expireMinutes * 60_000);
    const topUp = await this.repo.create({
      driverId: input.driverId,
      provider: this.provider,
      amountVnd: input.amountVnd,
      idempotencyKey: key,
      expiresAt,
    });

    try {
      const created = await adapter.create({
        orderRef: this.orderRef(topUp.orderCode),
        amountVnd: topUp.amountVnd,
        orderInfo: this.orderInfo(topUp.orderCode),
        returnUrl: `${baseUrl}/v1/payments/driver-credit/return/${this.provider}?orderCode=${topUp.orderCode}`,
        cancelUrl: `${baseUrl}/v1/payments/driver-credit/return/${this.provider}?orderCode=${topUp.orderCode}&cancelled=1`,
        ipnUrl: `${baseUrl}/v1/payments/ipn/${this.provider}`,
        clientIp: '127.0.0.1',
        userRef: input.driverId,
        methodCode: 'DRIVER_TOP_UP',
        now,
      });
      const attached = await this.repo.attachLink(topUp.id, {
        providerRef: created.providerRef,
        paymentLinkId: null,
        checkoutUrl: created.paymentUrl,
        qrCode: created.qrCode ?? null,
      });
      return toView(attached);
    } catch (error) {
      const message =
        error instanceof PaymentAdapterError
          ? error.message
          : error instanceof Error
            ? error.message
            : 'Payment provider error';
      this.logger.warn(`Driver top-up ${topUp.id} create failed: ${message}`);
      await this.repo.close(topUp.id, 'FAILED', message.slice(0, 255));
      fail(502, 'DRIVER_TOP_UP_PROVIDER_ERROR', 'Could not create the payment link');
    }
  }

  async cancelTopUp(driverId: string, topUpId: string): Promise<DriverTopUpView> {
    const row = await this.repo.findById(topUpId);
    if (!row || row.driverId !== driverId) {
      fail(404, 'DRIVER_TOP_UP_NOT_FOUND', 'Top-up not found');
    }
    if (row.status !== 'PENDING') {
      fail(409, 'DRIVER_TOP_UP_NOT_PENDING', 'Only a pending top-up can be cancelled');
    }
    const closed = await this.repo.close(row.id, 'CANCELLED', 'Cancelled by driver');
    const view = toView(closed ?? row);
    if (closed) {
      this.publish(closed, 'CANCELLED');
    }
    return view;
  }

  /** True when a callback belongs to a driver prepayment rather than a job checkout. */
  isDriverTopUpCallback(provider: string, payload: Record<string, unknown>): boolean {
    if (provider === 'payos') {
      return true;
    }
    if (provider === 'vnpay') {
      const ref = payload.vnp_TxnRef;
      return typeof ref === 'string' && ref.startsWith('DGCT');
    }
    return false;
  }

  async handleProviderCallback(
    providerRaw: string,
    payload: Record<string, unknown>,
  ): Promise<CallbackAck> {
    const provider = this.providerName(providerRaw);
    if (!provider) {
      return { httpStatus: 404, body: { message: 'Unknown provider' } };
    }
    const adapter = this.adapters[provider];
    if (!adapter) {
      return { httpStatus: 404, body: { message: 'Unknown provider' } };
    }
    const callback = adapter.verifyCallback(payload);
    if (!callback.valid) {
      return adapter.ack('INVALID_SIGNATURE');
    }
    if (!callback.providerRef) {
      return adapter.ack('NOT_FOUND');
    }
    if (!callback.success) {
      const row = await this.repo.findByProviderRef(provider, callback.providerRef);
      await this.repo.closeByProviderRef(
        provider,
        callback.providerRef,
        'FAILED',
        callback.failureReason,
      );
      if (row) {
        this.publish(row, 'FAILED');
      }
      return adapter.ack('OK');
    }
    if (callback.amountVnd === null) {
      return adapter.ack('AMOUNT_MISMATCH');
    }
    const result = await this.repo.capture({
      provider,
      providerRef: callback.providerRef,
      amountVnd: callback.amountVnd,
      providerTransId: callback.providerTransId,
      paidAt: new Date(),
    });
    switch (result) {
      case 'CAPTURED': {
        const row = await this.repo.findByProviderRef(provider, callback.providerRef);
        if (row) {
          this.publish(row, 'PAID');
        }
        return adapter.ack('OK');
      }
      case 'ALREADY':
        return adapter.ack('ALREADY');
      case 'AMOUNT_MISMATCH':
        return adapter.ack('AMOUNT_MISMATCH');
      case 'NOT_FOUND':
        return adapter.ack('NOT_FOUND');
      default:
        return adapter.ack('ERROR');
    }
  }

  /** Queries the PSP for pending links so a missed callback still credits the driver. */
  async reconcilePending(now = new Date()): Promise<{
    checked: number;
    captured: number;
    closed: number;
  }> {
    const adapter = this.adapter();
    if (!adapter.isConfigured()) {
      return { checked: 0, captured: 0, closed: 0 };
    }
    const rows = await this.repo.pendingOlderThan(new Date(now.getTime() - 60_000), 25);
    let captured = 0;
    let closed = 0;
    for (const row of rows) {
      if (!row.providerRef) {
        continue;
      }
      try {
        const result = await adapter.query({
          providerRef: row.providerRef,
          attemptedAt: row.createdAt,
          requestId: row.id,
          clientIp: '127.0.0.1',
          now,
        });
        if (result.state === 'CAPTURED' && result.amountVnd === row.amountVnd) {
          const status = await this.repo.capture({
            provider: row.provider,
            providerRef: row.providerRef,
            amountVnd: result.amountVnd,
            providerTransId: result.providerTransId,
            paidAt: now,
          });
          if (status === 'CAPTURED') {
            captured += 1;
            this.publish(row, 'PAID');
          }
          continue;
        }
        const expired = row.expiresAt ? row.expiresAt.getTime() <= now.getTime() : false;
        if (result.state === 'FAILED' || result.state === 'UNKNOWN' || expired) {
          const didClose = await this.repo.closeByProviderRef(
            row.provider,
            row.providerRef,
            result.state === 'FAILED' ? 'FAILED' : 'EXPIRED',
            result.message,
          );
          if (didClose) {
            closed += 1;
            this.publish(row, result.state === 'FAILED' ? 'FAILED' : 'EXPIRED');
          }
        }
      } catch (error) {
        this.logger.warn(
          `Driver top-up reconcile ${row.id} failed: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }
    }
    return { checked: rows.length, captured, closed };
  }

  async opsList(filter: {
    driverId?: string;
    status?: DriverTopUpRecord['status'];
    limit?: number;
  }): Promise<OpsDriverTopUpView[]> {
    const rows = await this.repo.listOps({
      driverId: filter.driverId,
      status: filter.status,
      limit: clampLimit(filter.limit ?? 50),
    });
    return rows.map(toOpsView);
  }

  async opsDetail(topUpId: string): Promise<OpsDriverTopUpView> {
    const row = await this.repo.findOpsById(topUpId);
    if (!row) {
      fail(404, 'DRIVER_TOP_UP_NOT_FOUND', 'Top-up not found');
    }
    return toOpsView(row);
  }

  async opsSummary(now = new Date()): Promise<DriverTopUpSummary> {
    const shifted = now.getTime() + VN_OFFSET_MS;
    const dayStart = new Date(Math.floor(shifted / 86_400_000) * 86_400_000 - VN_OFFSET_MS);
    return this.repo.opsSummary(dayStart);
  }

  async reconcileOne(topUpId: string): Promise<DriverTopUpView> {
    const row = await this.repo.findById(topUpId);
    if (!row) {
      fail(404, 'DRIVER_TOP_UP_NOT_FOUND', 'Top-up not found');
    }
    if (row.status !== 'PENDING' || !row.providerRef) {
      return toView(row);
    }
    const adapter = this.adapters[this.providerName(row.provider) ?? this.provider];
    if (!adapter || !adapter.isConfigured()) {
      fail(503, 'DRIVER_TOP_UP_PROVIDER_NOT_CONFIGURED', 'Payment provider is not configured');
    }
    const now = new Date();
    const result = await adapter.query({
      providerRef: row.providerRef,
      attemptedAt: row.createdAt,
      requestId: row.id,
      clientIp: '127.0.0.1',
      now,
    });
    if (result.state === 'CAPTURED' && result.amountVnd === row.amountVnd) {
      const status = await this.repo.capture({
        provider: row.provider,
        providerRef: row.providerRef,
        amountVnd: result.amountVnd,
        providerTransId: result.providerTransId,
        paidAt: now,
      });
      if (status === 'CAPTURED') {
        this.publish(row, 'PAID');
      }
    }
    const fresh = await this.repo.findById(row.id);
    return toView(fresh ?? row);
  }

  async refundTopUp(input: {
    actorUserId: string;
    topUpId: string;
    reason: string;
    bankRef: string;
  }): Promise<DriverTopUpView> {
    const reason = input.reason.trim();
    const bankRef = input.bankRef.trim();
    if (reason.length < 5) {
      fail(400, 'DRIVER_CREDIT_REFUND_REASON_REQUIRED', 'A refund reason is required');
    }
    if (bankRef.length < 3) {
      fail(400, 'DRIVER_CREDIT_REFUND_BANK_REF_REQUIRED', 'The bank transfer reference is required');
    }
    const result = await this.repo.refund({
      topUpId: input.topUpId,
      actorUserId: input.actorUserId,
      reason,
      bankRef,
      at: new Date(),
    });
    if (result === 'NOT_FOUND') {
      fail(404, 'DRIVER_TOP_UP_NOT_FOUND', 'Top-up not found');
    }
    if (result === 'NOT_REFUNDABLE') {
      fail(409, 'DRIVER_CREDIT_NOT_REFUNDABLE', 'Only a paid top-up can be refunded');
    }
    if (result === 'NOTHING_LEFT') {
      fail(409, 'DRIVER_CREDIT_NOTHING_TO_REFUND', 'No unused credit remains on this top-up');
    }
    this.publish(result.topUp, 'REFUNDED');
    return toView(result.topUp);
  }

  private publish(row: DriverTopUpRecord, status: DriverTopUpStatusName): void {
    this.bus.publish({
      driverId: row.driverId,
      topUpId: row.id,
      status,
      occurredAt: new Date().toISOString(),
    });
  }

  private async limits() {
    const [enabled, minVnd, maxVnd, dailyLimitVnd, maxCreditVnd, expireMinutes] =
      await Promise.all([
        this.settings.getBoolean('DRIVER_TOP_UP_ENABLED'),
        this.settings.getNumber('DRIVER_TOP_UP_MIN_VND'),
        this.settings.getNumber('DRIVER_TOP_UP_MAX_VND'),
        this.settings.getNumber('DRIVER_TOP_UP_DAILY_LIMIT_VND'),
        this.settings.getNumber('DRIVER_CREDIT_MAX_VND'),
        this.settings.getNumber('DRIVER_TOP_UP_EXPIRE_MINUTES'),
      ]);
    return {
      enabled: enabled === true,
      minVnd,
      maxVnd,
      dailyLimitVnd,
      maxCreditVnd,
      expireMinutes: expireMinutes > 0 ? expireMinutes : DEFAULT_EXPIRE_MINUTES,
    };
  }

  private async requireDriver(driverId: string): Promise<void> {
    const grants = await this.identity.listGrants(driverId);
    if (!grants.some((grant) => grant.role === 'DRIVER' && grant.status === 'ACTIVE')) {
      fail(403, 'ROLE_NOT_ACTIVE', 'An active driver role is required');
    }
  }

  private adapter(): PaymentAdapter {
    const adapter = this.adapters[this.provider];
    if (!adapter) {
      fail(503, 'DRIVER_TOP_UP_PROVIDER_NOT_CONFIGURED', 'Payment provider is not configured');
    }
    return adapter;
  }

  private providerName(raw: string): DriverTopUpProviderName | null {
    if (raw === 'payos' || raw === 'vnpay') {
      return raw;
    }
    return null;
  }

  private publicBaseUrl(): string | null {
    const base = this.config?.get('PAYMENT_PUBLIC_BASE_URL', { infer: true });
    return base ? base.replace(/\/+$/, '') : null;
  }

  private orderRef(orderCode: number): string {
    return this.provider === 'vnpay' ? `DGCT${orderCode}` : String(orderCode);
  }

  private orderInfo(orderCode: number): string {
    return this.provider === 'vnpay'
      ? `DealGo nap tien tai xe ${orderCode}`
      : `DG ${orderCode}`;
  }

  private isOpen(row: DriverTopUpRecord): boolean {
    return row.status === 'PENDING' && (!row.expiresAt || row.expiresAt.getTime() > Date.now());
  }
}

function toView(row: DriverTopUpRecord): DriverTopUpView {
  return {
    id: row.id,
    amountVnd: row.amountVnd,
    remainingVnd: row.remainingVnd,
    consumedVnd: row.consumedVnd,
    refundedVnd: row.refundedVnd,
    orderCode: row.orderCode,
    provider: row.provider,
    status: row.status,
    checkoutUrl: row.checkoutUrl,
    qrCode: row.qrCode,
    expiresAt: row.expiresAt?.toISOString() ?? null,
    paidAt: row.paidAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
  };
}

function toOpsView(row: OpsDriverTopUpRecord): OpsDriverTopUpView {
  return {
    ...toView(row),
    driverId: row.driverId,
    driverName: row.driverName,
    driverPhone: row.driverPhone,
    providerRef: row.providerRef,
    providerTransId: row.providerTransId,
    failureReason: row.failureReason,
    refundedAt: row.refundedAt?.toISOString() ?? null,
    refundBankRef: row.refundBankRef,
    refundReason: row.refundReason,
  };
}

function clampLimit(value: number): number {
  if (!Number.isFinite(value)) {
    return 20;
  }
  return Math.min(Math.max(Math.trunc(value), 1), 100);
}

function startOfVnDay(now: Date): Date {
  const shifted = new Date(now.getTime() + VN_OFFSET_MS);
  return new Date(
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()) - VN_OFFSET_MS,
  );
}

function fail(status: number, errorCode: string, message: string): never {
  throw new HttpException({ message, errorCode }, status);
}
