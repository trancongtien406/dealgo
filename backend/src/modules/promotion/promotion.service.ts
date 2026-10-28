import { randomInt } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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
import { evaluateVoucher, percentVoucherDiscountVnd } from './promotion-redemption.js';

export interface ListPromotionsQuery {
  page?: number;
  limit?: number;
  q?: string;
  status?: PromotionStatus | 'ALL';
  serviceType?: PromotionServiceType;
  audience?: PromotionAudience;
  scope?: 'STORE' | 'PLATFORM';
  storeId?: string;
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
  /** Set for a store's own offer; it only applies to orders from that store. */
  storeId: string | null;
};

/** A store's running offer as shown on store cards and the store page. */
export type StoreOffer = {
  id: string;
  code: string;
  name: string;
  discountType: 'FIXED_AMOUNT' | 'PERCENTAGE';
  discountValue: number;
  maxDiscountVnd: number | null;
  minOrderVnd: number;
  endsAt: string;
  /** Redemptions left before the offer is used up (usageLimit − usedCount). */
  remainingUses: number;
};

export type MerchantOfferInput = {
  name: string;
  code?: string;
  discountType: 'FIXED_AMOUNT' | 'PERCENTAGE';
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  usageLimit: number;
  userLimit?: number;
  startDate: string;
  endDate: string;
};

export type MerchantOfferStatus = 'ACTIVE' | 'PAUSED' | 'ENDED';

/** Running or paused offers one store may hold at once. */
export const STORE_OFFER_ACTIVE_LIMIT = 10;
export const STORE_OFFER_MAX_DAYS = 180;
const STORE_OFFERS_PER_CARD = 3;
const MAX_INT_VND = 2_147_483_647;
const OFFER_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

@Injectable()
export class PromotionService {
  constructor(
    @Inject(PROMOTION_REPOSITORY)
    private readonly repository: PromotionRepository,
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
        query.serviceType && query.serviceType !== 'ALL'
          ? query.serviceType
          : undefined,
      audience:
        query.audience && query.audience !== 'ALL' ? query.audience : undefined,
      scope: query.scope,
      storeId: query.storeId,
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
      throw new NotFoundException(
        `Không tìm thấy chiến dịch khuyến mãi với ID ${id}`,
      );
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
      throw new BadRequestException(
        'Thời gian kết thúc phải sau thời gian bắt đầu.',
      );
    }

    if (
      dto.serviceType === 'RIDE' &&
      (dto.sponsor ?? 'PLATFORM') !== 'PLATFORM'
    ) {
      throw new BadRequestException(
        'Ưu đãi chuyến xe chỉ do DealGo tài trợ (DEC-PROD-024).',
      );
    }
    if (
      dto.serviceType === 'RIDE' &&
      dto.discountType === 'DELIVERY_DISCOUNT'
    ) {
      throw new BadRequestException(
        'Chuyến xe không có phí giao hàng để giảm.',
      );
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
        throw new BadRequestException(
          `Mã voucher '${normalizedCode}' đã tồn tại.`,
        );
      }
      throw error;
    }
  }

  async updateStatus(
    id: string,
    newStatus: PromotionStatus,
    audit?: { actorUserId: string; reason?: string },
  ): Promise<PromotionCampaign> {
    const updated = await this.repository.updateStatus(
      id,
      newStatus,
      audit
        ? {
            actorUserId: audit.actorUserId,
            reason: audit.reason?.trim() || `Đổi trạng thái thành ${newStatus}`,
          }
        : undefined,
    );
    if (!updated) {
      throw new NotFoundException(
        `Không tìm thấy chiến dịch khuyến mãi với ID ${id}`,
      );
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
    storeId?: string,
    now = new Date(),
  ): Promise<CustomerVoucher[]> {
    const campaigns = (
      await this.repository.listAvailable(now, CUSTOMER_VOUCHER_LIMIT, storeId)
    ).filter(
      (c) =>
        (!serviceType ||
          c.serviceType === 'ALL' ||
          c.serviceType === serviceType) &&
        // DEC-PROD-024: only DealGo-funded, non-delivery campaigns can discount a ride.
        (serviceType !== 'RIDE' ||
          (c.sponsor === 'PLATFORM' && c.discountType !== 'DELIVERY_DISCOUNT')),
    );
    const used = await Promise.all(
      campaigns.map((c) =>
        this.repository.countUserRedemptions(c.id, customerId),
      ),
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
        storeId: c.storeId ?? null,
      }));
  }

  /** Running offers per store for browse cards and the store page, best value first. */
  async storeOffers(
    storeIds: string[],
    perStore = STORE_OFFERS_PER_CARD,
    now = new Date(),
  ): Promise<Map<string, StoreOffer[]>> {
    const unique = [...new Set(storeIds)];
    const byStore = new Map<string, StoreOffer[]>();
    if (unique.length === 0) {
      return byStore;
    }
    const rows = await this.repository.listStoreOffers(unique, now);
    for (const c of rows) {
      if (
        !c.storeId ||
        (c.discountType !== 'FIXED_AMOUNT' && c.discountType !== 'PERCENTAGE')
      ) {
        continue;
      }
      const list = byStore.get(c.storeId) ?? [];
      list.push({
        id: c.id,
        code: c.code,
        name: c.name,
        discountType: c.discountType,
        discountValue: c.discountValue,
        maxDiscountVnd: c.maxDiscountAmount ?? null,
        minOrderVnd: c.minOrderAmount,
        endsAt: c.endDate,
        remainingUses: Math.max(0, c.usageLimit - c.usedCount),
      });
      byStore.set(c.storeId, list);
    }
    for (const [storeId, list] of byStore) {
      byStore.set(storeId, list.sort(compareOfferValue).slice(0, perStore));
    }
    return byStore;
  }

  async listStoreOffersForMerchant(
    storeId: string,
  ): Promise<PromotionCampaign[]> {
    const { items } = await this.repository.list({ storeId }, 1, 100);
    return items;
  }

  /** A merchant-funded FOOD offer that only applies inside the merchant's own store. */
  async createStoreOffer(
    storeId: string,
    input: MerchantOfferInput,
    now = new Date(),
  ): Promise<PromotionCampaign> {
    const startDate = new Date(input.startDate);
    const endDate = new Date(input.endDate);
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      throw offerError('PROMOTION_DATES_INVALID', 'Thời gian không hợp lệ.');
    }
    if (endDate <= startDate || endDate <= now) {
      throw offerError(
        'PROMOTION_DATES_INVALID',
        'Thời gian kết thúc phải sau thời gian bắt đầu.',
      );
    }
    if (
      endDate.getTime() - startDate.getTime() >
      STORE_OFFER_MAX_DAYS * 86_400_000
    ) {
      throw offerError(
        'PROMOTION_DATES_INVALID',
        `Ưu đãi kéo dài tối đa ${STORE_OFFER_MAX_DAYS} ngày.`,
      );
    }
    if (input.discountType === 'PERCENTAGE') {
      if (input.discountValue < 1 || input.discountValue > 100) {
        throw offerError(
          'PROMOTION_VALUE_INVALID',
          'Phần trăm giảm từ 1 đến 100.',
        );
      }
      if (!input.maxDiscountAmount) {
        throw offerError(
          'PROMOTION_CAP_REQUIRED',
          'Cần mức giảm tối đa cho ưu đãi phần trăm.',
        );
      }
    } else if (input.discountValue < 1000) {
      throw offerError(
        'PROMOTION_VALUE_INVALID',
        'Số tiền giảm tối thiểu 1.000đ.',
      );
    }
    if (
      input.discountType === 'FIXED_AMOUNT' &&
      input.minOrderAmount < input.discountValue
    ) {
      throw offerError(
        'PROMOTION_MIN_ORDER_INVALID',
        'Đơn tối thiểu phải lớn hơn hoặc bằng số tiền giảm.',
      );
    }
    const current = await this.listStoreOffersForMerchant(storeId);
    const live = current.filter(
      (c) =>
        (c.status === 'ACTIVE' || c.status === 'PAUSED') &&
        Date.parse(c.endDate) > now.getTime(),
    );
    if (live.length >= STORE_OFFER_ACTIVE_LIMIT) {
      throw offerError(
        'PROMOTION_STORE_LIMIT',
        `Mỗi cửa hàng chạy tối đa ${STORE_OFFER_ACTIVE_LIMIT} ưu đãi cùng lúc.`,
      );
    }
    const perUseCap =
      input.discountType === 'FIXED_AMOUNT'
        ? input.discountValue
        : (input.maxDiscountAmount ?? 0);
    const totalBudget = Math.min(MAX_INT_VND, perUseCap * input.usageLimit);
    const requested = input.code ? normalizeCode(input.code) : undefined;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const code = requested ?? generateOfferCode();
      try {
        return await this.repository.create({
          code,
          name: input.name.trim(),
          description: '',
          serviceType: 'FOOD',
          discountType: input.discountType,
          discountValue: input.discountValue,
          maxDiscountAmount:
            input.discountType === 'PERCENTAGE'
              ? input.maxDiscountAmount
              : undefined,
          minOrderAmount: Math.max(0, input.minOrderAmount),
          totalBudget,
          usageLimit: input.usageLimit,
          userLimit: Math.max(1, input.userLimit ?? 1),
          targetAudience: 'CUSTOMER',
          status: 'ACTIVE',
          startDate,
          endDate,
          sponsor: 'MERCHANT',
          storeId,
        });
      } catch (error) {
        if (!(error instanceof PromotionCodeConflictError)) {
          throw error;
        }
        if (requested) {
          throw new ConflictException({
            message: `Mã '${requested}' đã được dùng.`,
            errorCode: 'PROMOTION_CODE_TAKEN',
          });
        }
      }
    }
    throw offerError('PROMOTION_CODE_TAKEN', 'Không tạo được mã, thử lại.');
  }

  /** Pause, resume or end the store's own offer. An offer ops cancelled stays cancelled. */
  async setStoreOfferStatus(
    storeId: string,
    id: string,
    status: MerchantOfferStatus,
  ): Promise<PromotionCampaign> {
    const campaign = await this.repository.findById(id);
    if (!campaign || campaign.storeId !== storeId) {
      throw new NotFoundException({
        message: 'Không tìm thấy ưu đãi.',
        errorCode: 'PROMOTION_NOT_FOUND',
      });
    }
    if (campaign.status === 'CANCELLED' || campaign.status === 'ENDED') {
      throw new ConflictException({
        message: 'Ưu đãi đã kết thúc.',
        errorCode: 'PROMOTION_CLOSED',
      });
    }
    return this.updateStatus(id, status);
  }

  async validateAndCalculate(
    input: ValidatePromotionInput,
  ): Promise<ValidatePromotionResult> {
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
      ? await this.repository.countUserRedemptions(
          campaign.id,
          input.customerId,
        )
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

function offerError(errorCode: string, message: string): BadRequestException {
  return new BadRequestException({ message, errorCode });
}

function generateOfferCode(): string {
  let code = 'CH';
  for (let i = 0; i < 6; i += 1) {
    code += OFFER_CODE_ALPHABET[randomInt(OFFER_CODE_ALPHABET.length)];
  }
  return code;
}

/** Rough value at the minimum order, so cards lead with the strongest offer. */
function offerValueVnd(offer: StoreOffer): number {
  if (offer.discountType === 'FIXED_AMOUNT') {
    return offer.discountValue;
  }
  return percentVoucherDiscountVnd(
    Math.max(offer.minOrderVnd, 100_000),
    offer.discountValue,
    offer.maxDiscountVnd,
  );
}

function compareOfferValue(a: StoreOffer, b: StoreOffer): number {
  return (
    offerValueVnd(b) - offerValueVnd(a) ||
    a.minOrderVnd - b.minOrderVnd ||
    a.code.localeCompare(b.code)
  );
}

function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}
