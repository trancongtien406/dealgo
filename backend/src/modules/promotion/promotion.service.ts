import { BadRequestException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PROMOTION_REPOSITORY } from './promotion.constants.js';
import {
  PromotionCodeConflictError,
  type PromotionListFilter,
  type PromotionRepository,
} from './promotion.repository.js';
import type {
  PromotionCampaign,
  PromotionKpiSummary,
  ValidatePromotionInput,
  ValidatePromotionResult,
  PromotionStatus,
  PromotionServiceType,
  PromotionAudience,
} from './promotion.types.js';
import { evaluateVoucher } from './promotion-redemption.js';

export interface ListPromotionsQuery {
  page?: number;
  limit?: number;
  q?: string;
  status?: PromotionStatus | 'ALL';
  serviceType?: PromotionServiceType;
  audience?: PromotionAudience;
}

export interface CreatePromotionDto {
  code: string;
  name: string;
  description: string;
  serviceType: PromotionServiceType;
  discountType: 'FIXED_AMOUNT' | 'PERCENTAGE' | 'DELIVERY_DISCOUNT';
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  totalBudget: number;
  usageLimit: number;
  userLimit?: number;
  targetAudience?: PromotionAudience;
  startDate: string;
  endDate: string;
  sponsor?: 'PLATFORM' | 'MERCHANT' | 'SHARED';
}

export const CUSTOMER_VOUCHER_LIMIT = 20;

export type CustomerVoucher = {
  code: string;
  name: string;
  description: string;
  serviceType: PromotionCampaign['serviceType'];
  discountType: PromotionCampaign['discountType'];
  discountValue: number;
  maxDiscountVnd: number | null;
  minOrderVnd: number;
  endsAt: string;
  usesLeft: number;
};

@Injectable()
export class PromotionService {
  constructor(
    @Inject(PROMOTION_REPOSITORY) private readonly repository: PromotionRepository,
  ) {}

  async listPromotions(query: ListPromotionsQuery = {}): Promise<{
    items: PromotionCampaign[];
    total: number;
    page: number;
    limit: number;
    kpi: PromotionKpiSummary;
  }> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.max(1, Math.min(100, query.limit ?? 10));
    const filter: PromotionListFilter = {
      q: query.q?.trim() || undefined,
      status: query.status && query.status !== 'ALL' ? query.status : undefined,
      serviceType:
        query.serviceType && query.serviceType !== 'ALL' ? query.serviceType : undefined,
      audience: query.audience && query.audience !== 'ALL' ? query.audience : undefined,
    };

    // KPI covers every campaign, independent of the current filter.
    const [{ items, total }, kpi] = await Promise.all([
      this.repository.list(filter, page, limit),
      this.repository.kpi(),
    ]);
    return { items, total, page, limit, kpi };
  }

  async getById(id: string): Promise<PromotionCampaign> {
    const campaign = await this.repository.findById(id);
    if (!campaign) {
      throw new NotFoundException(`Không tìm thấy chiến dịch khuyến mãi với ID ${id}`);
    }
    return campaign;
  }

  async getByCode(code: string): Promise<PromotionCampaign | null> {
    return this.repository.findByCode(normalizeCode(code));
  }

  async create(dto: CreatePromotionDto): Promise<PromotionCampaign> {
    const normalizedCode = normalizeCode(dto.code);
    const startDate = new Date(dto.startDate);
    const endDate = new Date(dto.endDate);
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      throw new BadRequestException('Thời gian bắt đầu/kết thúc không hợp lệ.');
    }
    if (endDate <= startDate) {
      throw new BadRequestException('Thời gian kết thúc phải sau thời gian bắt đầu.');
    }

    if (dto.serviceType === 'RIDE' && (dto.sponsor ?? 'PLATFORM') !== 'PLATFORM') {
      throw new BadRequestException('Ưu đãi chuyến xe chỉ do DealGo tài trợ (DEC-PROD-024).');
    }
    if (dto.serviceType === 'RIDE' && dto.discountType === 'DELIVERY_DISCOUNT') {
      throw new BadRequestException('Chuyến xe không có phí giao hàng để giảm.');
    }
    try {
      return await this.repository.create({
        code: normalizedCode,
        name: dto.name.trim(),
        description: dto.description.trim(),
        serviceType: dto.serviceType,
        discountType: dto.discountType,
        discountValue: Math.max(0, dto.discountValue),
        maxDiscountAmount: dto.maxDiscountAmount,
        minOrderAmount: Math.max(0, dto.minOrderAmount),
        totalBudget: Math.max(0, dto.totalBudget),
        usageLimit: Math.max(1, dto.usageLimit),
        userLimit: Math.max(1, dto.userLimit ?? 1),
        targetAudience: dto.targetAudience ?? 'ALL',
        status: 'ACTIVE',
        startDate,
        endDate,
        sponsor: dto.sponsor ?? 'PLATFORM',
      });
    } catch (error) {
      if (error instanceof PromotionCodeConflictError) {
        throw new BadRequestException(`Mã voucher '${normalizedCode}' đã tồn tại.`);
      }
      throw error;
    }
  }

  async updateStatus(id: string, newStatus: PromotionStatus): Promise<PromotionCampaign> {
    const updated = await this.repository.updateStatus(id, newStatus);
    if (!updated) {
      throw new NotFoundException(`Không tìm thấy chiến dịch khuyến mãi với ID ${id}`);
    }
    return updated;
  }

  /**
   * Quote-only check for checkout: it does not reserve budget or record a redemption.
   * The binding check runs again inside the place-order transaction.
   */
  /**
   * Vouchers a customer can still use, without internal budget/sponsor fields.
   * Campaigns the customer already used up (userLimit) are left out.
   */
  async listAvailableForCustomer(
    customerId: string,
    serviceType?: 'RIDE' | 'FOOD',
    now = new Date(),
  ): Promise<CustomerVoucher[]> {
    const campaigns = (await this.repository.listAvailable(now, CUSTOMER_VOUCHER_LIMIT)).filter(
      (c) =>
        (!serviceType || c.serviceType === 'ALL' || c.serviceType === serviceType) &&
        // DEC-PROD-024: only DealGo-funded, non-delivery campaigns can discount a ride.
        (serviceType !== 'RIDE' ||
          (c.sponsor === 'PLATFORM' && c.discountType !== 'DELIVERY_DISCOUNT')),
    );
    const used = await Promise.all(
      campaigns.map((c) => this.repository.countUserRedemptions(c.id, customerId)),
    );
    return campaigns
      .map((c, i) => ({ c, usesLeft: c.userLimit - used[i] }))
      .filter(({ usesLeft }) => usesLeft > 0)
      .map(({ c, usesLeft }) => ({
        code: c.code,
        name: c.name,
        description: c.description,
        serviceType: c.serviceType,
        discountType: c.discountType,
        discountValue: c.discountValue,
        maxDiscountVnd: c.maxDiscountAmount ?? null,
        minOrderVnd: c.minOrderAmount,
        endsAt: c.endDate,
        usesLeft,
      }));
  }

  async validateAndCalculate(input: ValidatePromotionInput): Promise<ValidatePromotionResult> {
    const campaign = await this.getByCode(input.voucherCode);
    if (!campaign) {
      return {
        valid: false,
        code: input.voucherCode,
        discountAmount: 0,
        finalAmount: input.orderAmount,
        reason: `Mã voucher '${input.voucherCode}' không tồn tại.`,
        rejectCode: 'VOUCHER_NOT_FOUND',
      };
    }
    const userRedemptions = input.customerId
      ? await this.repository.countUserRedemptions(campaign.id, input.customerId)
      : 0;
    const verdict = evaluateVoucher(campaign, input, userRedemptions);
    if (!verdict.ok) {
      return {
        valid: false,
        code: campaign.code,
        discountAmount: 0,
        finalAmount: input.orderAmount,
        reason: verdict.reason,
        rejectCode: verdict.code,
      };
    }
    return {
      valid: true,
      code: campaign.code,
      discountAmount: verdict.discountVnd,
      finalAmount: verdict.finalAmount,
      campaign: {
        id: campaign.id,
        name: campaign.name,
        discountType: campaign.discountType,
        discountValue: campaign.discountValue,
      },
    };
  }
}

function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}
