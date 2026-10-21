import { randomUUID } from 'node:crypto';
import type {
  DiscountType,
  PromotionAudience,
  PromotionCampaign,
  PromotionKpiSummary,
  PromotionServiceType,
  PromotionSponsor,
  PromotionStatus,
} from './promotion.types.js';
import {
  evaluateVoucher,
  normalizeVoucherCode,
  VoucherRejectedError,
  type RedeemVoucherInput,
  type RedeemVoucherResult,
  type ReleaseVoucherInput,
  type VoucherRedeemer,
} from './promotion-redemption.js';

export class PromotionCodeConflictError extends Error {
  constructor() {
    super('Promotion code already exists');
    this.name = 'PromotionCodeConflictError';
  }
}

export type PromotionListFilter = {
  q?: string;
  status?: PromotionStatus;
  serviceType?: Exclude<PromotionServiceType, 'ALL'>;
  audience?: Exclude<PromotionAudience, 'ALL'>;
};

export type NewPromotion = {
  code: string;
  name: string;
  description: string;
  serviceType: PromotionServiceType;
  discountType: DiscountType;
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  totalBudget: number;
  usageLimit: number;
  userLimit: number;
  targetAudience: PromotionAudience;
  status: PromotionStatus;
  startDate: Date;
  endDate: Date;
  sponsor: PromotionSponsor;
};

export interface PromotionRepository extends VoucherRedeemer {
  list(
    filter: PromotionListFilter,
    page: number,
    limit: number,
  ): Promise<{ items: PromotionCampaign[]; total: number }>;
  kpi(): Promise<PromotionKpiSummary>;
  findById(id: string): Promise<PromotionCampaign | null>;
  /** `code` must already be normalized to upper case. */
  findByCode(code: string): Promise<PromotionCampaign | null>;
  create(input: NewPromotion): Promise<PromotionCampaign>;
  updateStatus(
    id: string,
    status: PromotionStatus,
  ): Promise<PromotionCampaign | null>;
  /** Orders this user already paid with the campaign (drives `userLimit`). */
  countUserRedemptions(promotionId: string, userId: string): Promise<number>;
  /**
   * ACTIVE customer-facing campaigns running at `now` with budget and usage left,
   * soonest-ending first (DEC-PROD-021).
   */
  listAvailable(now: Date, limit: number): Promise<PromotionCampaign[]>;
}

/** Test-only store; production resolves PrismaPromotionRepository. */
export class MemoryPromotionRepository implements PromotionRepository {
  private readonly byId = new Map<string, PromotionCampaign>();
  private readonly redemptions: {
    promotionId: string;
    userId: string;
    entityKey: string;
    discountVnd: number;
    released: boolean;
  }[] = [];

  constructor(seed: readonly PromotionCampaign[] = []) {
    for (const item of seed) {
      this.byId.set(item.id, { ...item });
    }
  }

  async list(
    filter: PromotionListFilter,
    page: number,
    limit: number,
  ): Promise<{ items: PromotionCampaign[]; total: number }> {
    const needle = filter.q?.trim().toLowerCase();
    const rows = [...this.byId.values()]
      .filter(
        (c) =>
          !needle ||
          c.code.toLowerCase().includes(needle) ||
          c.name.toLowerCase().includes(needle) ||
          c.description.toLowerCase().includes(needle),
      )
      .filter((c) => !filter.status || c.status === filter.status)
      .filter(
        (c) =>
          !filter.serviceType ||
          c.serviceType === filter.serviceType ||
          c.serviceType === 'ALL',
      )
      .filter(
        (c) =>
          !filter.audience ||
          c.targetAudience === filter.audience ||
          c.targetAudience === 'ALL',
      )
      .sort(
        (a, b) =>
          Date.parse(b.createdAt) - Date.parse(a.createdAt) ||
          b.id.localeCompare(a.id),
      );
    const offset = (page - 1) * limit;
    return {
      items: rows.slice(offset, offset + limit).map((c) => ({ ...c })),
      total: rows.length,
    };
  }

  async kpi(): Promise<PromotionKpiSummary> {
    const all = [...this.byId.values()];
    return {
      totalCampaigns: all.length,
      activeCount: all.filter((c) => c.status === 'ACTIVE').length,
      scheduledCount: all.filter((c) => c.status === 'SCHEDULED').length,
      endedCount: all.filter(
        (c) => c.status === 'ENDED' || c.status === 'CANCELLED',
      ).length,
      totalBudgetCommitted: all.reduce((sum, c) => sum + c.totalBudget, 0),
      totalBudgetSpent: all.reduce((sum, c) => sum + c.usedBudget, 0),
      totalRedemptions: all.reduce((sum, c) => sum + c.usedCount, 0),
    };
  }

  async findById(id: string): Promise<PromotionCampaign | null> {
    const found = this.byId.get(id);
    return found ? { ...found } : null;
  }

  async listAvailable(now: Date, limit: number): Promise<PromotionCampaign[]> {
    const at = now.getTime();
    return [...this.byId.values()]
      .filter(
        (c) =>
          c.status === 'ACTIVE' &&
          (c.targetAudience === 'ALL' || c.targetAudience === 'CUSTOMER') &&
          Date.parse(c.startDate) <= at &&
          Date.parse(c.endDate) > at &&
          c.usedCount < c.usageLimit &&
          c.usedBudget < c.totalBudget,
      )
      .sort((a, b) => Date.parse(a.endDate) - Date.parse(b.endDate) || a.code.localeCompare(b.code))
      .slice(0, limit)
      .map((c) => ({ ...c }));
  }

  async findByCode(code: string): Promise<PromotionCampaign | null> {
    const found = [...this.byId.values()].find((c) => c.code === code);
    return found ? { ...found } : null;
  }

  async create(input: NewPromotion): Promise<PromotionCampaign> {
    if (await this.findByCode(input.code)) {
      throw new PromotionCodeConflictError();
    }
    const now = new Date().toISOString();
    const campaign: PromotionCampaign = {
      ...input,
      id: randomUUID(),
      usedBudget: 0,
      usedCount: 0,
      startDate: input.startDate.toISOString(),
      endDate: input.endDate.toISOString(),
      createdAt: now,
      updatedAt: now,
    };
    this.byId.set(campaign.id, campaign);
    return { ...campaign };
  }

  async updateStatus(
    id: string,
    status: PromotionStatus,
  ): Promise<PromotionCampaign | null> {
    const current = this.byId.get(id);
    if (!current) {
      return null;
    }
    const next = { ...current, status, updatedAt: new Date().toISOString() };
    this.byId.set(id, next);
    return { ...next };
  }

  async countUserRedemptions(promotionId: string, userId: string): Promise<number> {
    return this.redemptions.filter(
      (r) => r.promotionId === promotionId && r.userId === userId && !r.released,
    ).length;
  }

  async redeem(input: RedeemVoucherInput): Promise<RedeemVoucherResult> {
    const code = normalizeVoucherCode(input.code);
    const campaign = [...this.byId.values()].find((c) => c.code === code);
    if (!campaign) {
      throw new VoucherRejectedError('VOUCHER_NOT_FOUND', `Mã voucher '${code}' không tồn tại.`);
    }
    const entityKey = `${input.entityType}:${input.entityId}`;
    if (this.redemptions.some((r) => r.entityKey === entityKey && !r.released)) {
      throw new VoucherRejectedError('VOUCHER_USER_LIMIT', 'Đơn này đã áp dụng một mã khuyến mãi.');
    }
    // A ride sent back to negotiation may redeem again; the released row is replaced.
    const releasedIndex = this.redemptions.findIndex((r) => r.entityKey === entityKey);
    if (releasedIndex >= 0) {
      this.redemptions.splice(releasedIndex, 1);
    }
    const verdict = evaluateVoucher(
      campaign,
      input,
      await this.countUserRedemptions(campaign.id, input.userId),
    );
    if (!verdict.ok) {
      throw new VoucherRejectedError(verdict.code, verdict.reason);
    }
    this.byId.set(campaign.id, {
      ...campaign,
      usedCount: campaign.usedCount + 1,
      usedBudget: campaign.usedBudget + verdict.discountVnd,
      updatedAt: new Date().toISOString(),
    });
    this.redemptions.push({
      promotionId: campaign.id,
      userId: input.userId,
      entityKey,
      discountVnd: verdict.discountVnd,
      released: false,
    });
    return {
      promotionId: campaign.id,
      code: campaign.code,
      discountVnd: verdict.discountVnd,
      sponsor: campaign.sponsor,
    };
  }

  async release(input: ReleaseVoucherInput): Promise<boolean> {
    const entityKey = `${input.entityType}:${input.entityId}`;
    const row = this.redemptions.find((r) => r.entityKey === entityKey && !r.released);
    if (!row) {
      return false;
    }
    row.released = true;
    const campaign = this.byId.get(row.promotionId);
    if (campaign) {
      this.byId.set(campaign.id, {
        ...campaign,
        usedCount: Math.max(0, campaign.usedCount - 1),
        usedBudget: Math.max(0, campaign.usedBudget - row.discountVnd),
        updatedAt: new Date().toISOString(),
      });
    }
    return true;
  }
}
