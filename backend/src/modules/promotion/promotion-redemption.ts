import type { Prisma } from '../../generated/prisma/client.js';
import type { PromotionCampaign } from './promotion.types.js';

export type RedemptionEntityType = 'FOOD_ORDER' | 'RIDE';

export type VoucherRejectCode =
  | 'VOUCHER_NOT_FOUND'
  | 'VOUCHER_PAUSED'
  | 'VOUCHER_INACTIVE'
  | 'VOUCHER_NOT_STARTED'
  | 'VOUCHER_EXPIRED'
  | 'VOUCHER_WRONG_SERVICE'
  | 'VOUCHER_MIN_ORDER'
  | 'VOUCHER_USAGE_EXHAUSTED'
  | 'VOUCHER_BUDGET_EXHAUSTED'
  | 'VOUCHER_USER_LIMIT';

export type VoucherCheckInput = {
  serviceType: 'RIDE' | 'FOOD';
  orderAmount: number;
  deliveryFee?: number;
};

export type VoucherEvaluation =
  | { ok: true; discountVnd: number; finalAmount: number }
  | { ok: false; code: VoucherRejectCode; reason: string };

export type RedeemVoucherInput = VoucherCheckInput & {
  code: string;
  userId: string;
  entityType: RedemptionEntityType;
  entityId: string;
};

export type RedeemVoucherResult = {
  promotionId: string;
  code: string;
  discountVnd: number;
  /** Who funds the discount, snapshotted onto the order (DEC-PROD-015). */
  sponsor: PromotionCampaign['sponsor'];
};

export type ReleaseVoucherInput = {
  entityType: RedemptionEntityType;
  entityId: string;
};

export interface VoucherRedeemer {
  redeem(input: RedeemVoucherInput): Promise<RedeemVoucherResult>;
  /** Returns the use to the campaign. Idempotent: false when nothing was active. */
  release(input: ReleaseVoucherInput): Promise<boolean>;
}

export class VoucherRejectedError extends Error {
  readonly code: VoucherRejectCode;

  constructor(code: VoucherRejectCode, reason: string) {
    super(reason);
    this.name = 'VoucherRejectedError';
    this.code = code;
  }
}

export function normalizeVoucherCode(code: string): string {
  return code.trim().toUpperCase();
}

type EvaluableCampaign = Pick<
  PromotionCampaign,
  | 'code'
  | 'status'
  | 'startDate'
  | 'endDate'
  | 'serviceType'
  | 'minOrderAmount'
  | 'usedCount'
  | 'usageLimit'
  | 'usedBudget'
  | 'totalBudget'
  | 'userLimit'
  | 'discountType'
  | 'discountValue'
  | 'maxDiscountAmount'
> &
  Partial<Pick<PromotionCampaign, 'sponsor'>>;

/**
 * Pure rule check shared by the checkout quote and the redemption transaction.
 * `userRedemptions` is how many orders this user already paid with the campaign.
 */
export function evaluateVoucher(
  campaign: EvaluableCampaign,
  input: VoucherCheckInput,
  userRedemptions: number,
  now: Date = new Date(),
): VoucherEvaluation {
  const reject = (code: VoucherRejectCode, reason: string): VoucherEvaluation => ({
    ok: false,
    code,
    reason,
  });
  if (campaign.status === 'PAUSED') {
    return reject('VOUCHER_PAUSED', 'Chương trình khuyến mãi này đang tạm dừng.');
  }
  if (campaign.status !== 'ACTIVE') {
    return reject(
      'VOUCHER_INACTIVE',
      `Voucher không ở trạng thái hoạt động (Trạng thái: ${campaign.status}).`,
    );
  }
  const at = now.getTime();
  if (at < Date.parse(campaign.startDate)) {
    return reject('VOUCHER_NOT_STARTED', 'Chương trình khuyến mãi chưa bắt đầu.');
  }
  if (at > Date.parse(campaign.endDate)) {
    return reject('VOUCHER_EXPIRED', 'Chương trình khuyến mãi đã hết hạn sử dụng.');
  }
  if (campaign.serviceType !== 'ALL' && campaign.serviceType !== input.serviceType) {
    return reject(
      'VOUCHER_WRONG_SERVICE',
      `Mã khuyến mãi chỉ áp dụng cho dịch vụ ${campaign.serviceType}, không dùng được cho ${input.serviceType}.`,
    );
  }
  // DEC-PROD-024: a ride has no merchant to co-fund a discount, and no delivery fee.
  if (input.serviceType === 'RIDE' && campaign.discountType === 'DELIVERY_DISCOUNT') {
    return reject('VOUCHER_WRONG_SERVICE', 'Mã giảm phí giao hàng không áp dụng cho chuyến xe.');
  }
  if (
    input.serviceType === 'RIDE' &&
    campaign.sponsor !== undefined &&
    campaign.sponsor !== 'PLATFORM'
  ) {
    return reject(
      'VOUCHER_WRONG_SERVICE',
      'Mã do cửa hàng đồng tài trợ chỉ áp dụng cho đơn đồ ăn.',
    );
  }
  if (input.orderAmount < campaign.minOrderAmount) {
    return reject(
      'VOUCHER_MIN_ORDER',
      `Đơn hàng chưa đạt giá trị tối thiểu ${campaign.minOrderAmount.toLocaleString('vi-VN')}đ để dùng mã này.`,
    );
  }
  if (campaign.usedCount >= campaign.usageLimit) {
    return reject('VOUCHER_USAGE_EXHAUSTED', 'Mã khuyến mãi đã hết lượt sử dụng.');
  }
  if (userRedemptions >= campaign.userLimit) {
    return reject('VOUCHER_USER_LIMIT', 'Bạn đã dùng hết số lượt cho mã khuyến mãi này.');
  }

  const deliveryFee = input.deliveryFee ?? 0;
  let discount = 0;
  if (campaign.discountType === 'FIXED_AMOUNT') {
    discount = campaign.discountValue;
  } else if (campaign.discountType === 'PERCENTAGE') {
    const rawPercent = Math.round((input.orderAmount * campaign.discountValue) / 100);
    discount = campaign.maxDiscountAmount
      ? Math.min(rawPercent, campaign.maxDiscountAmount)
      : rawPercent;
  } else if (campaign.discountType === 'DELIVERY_DISCOUNT') {
    discount = Math.min(deliveryFee, campaign.discountValue);
  }
  const totalBill = input.orderAmount + deliveryFee;
  discount = Math.max(0, Math.round(Math.min(discount, totalBill)));
  if (campaign.usedBudget + discount > campaign.totalBudget) {
    return reject('VOUCHER_BUDGET_EXHAUSTED', 'Ngân sách của chương trình khuyến mãi đã hết.');
  }
  return { ok: true, discountVnd: discount, finalAmount: Math.max(0, totalBill - discount) };
}

type LockedPromotionRow = {
  id: string;
  code: string;
  status: PromotionCampaign['status'];
  serviceType: PromotionCampaign['serviceType'];
  discountType: PromotionCampaign['discountType'];
  discountValue: number;
  maxDiscountAmount: number | null;
  minOrderAmount: number;
  totalBudget: number;
  usedBudget: number;
  usageLimit: number;
  usedCount: number;
  userLimit: number;
  startDate: Date;
  endDate: Date;
  sponsor: PromotionCampaign['sponsor'];
};

/**
 * Re-checks and consumes a voucher inside the caller's transaction. The promotion row is
 * locked with FOR UPDATE, so concurrent checkouts on one campaign serialize and the
 * usage, per-user and budget limits cannot be overrun. Rolls back with the order.
 */
export async function redeemVoucherInTx(
  tx: Prisma.TransactionClient,
  input: RedeemVoucherInput,
  now: Date = new Date(),
): Promise<RedeemVoucherResult> {
  const code = normalizeVoucherCode(input.code);
  const rows = await tx.$queryRaw<LockedPromotionRow[]>`
    SELECT "id", "code", "status", "serviceType", "discountType", "discountValue",
           "maxDiscountAmount", "minOrderAmount", "totalBudget", "usedBudget",
           "usageLimit", "usedCount", "userLimit", "startDate", "endDate", "sponsor"
    FROM "promotions" WHERE "code" = ${code} FOR UPDATE`;
  const row = rows[0];
  if (!row) {
    throw new VoucherRejectedError('VOUCHER_NOT_FOUND', `Mã voucher '${code}' không tồn tại.`);
  }
  const userRedemptions = await tx.promotionRedemption.count({
    where: { promotionId: row.id, userId: input.userId, releasedAt: null },
  });
  const verdict = evaluateVoucher(
    {
      ...row,
      maxDiscountAmount: row.maxDiscountAmount ?? undefined,
      startDate: row.startDate.toISOString(),
      endDate: row.endDate.toISOString(),
    },
    input,
    userRedemptions,
    now,
  );
  if (!verdict.ok) {
    throw new VoucherRejectedError(verdict.code, verdict.reason);
  }
  // A ride sent back to negotiation (ops reassign) keeps its released row; reviving it keeps
  // the one-row-per-entity invariant. An active row means the entity already holds a voucher.
  const existing = await tx.promotionRedemption.findUnique({
    where: { entityType_entityId: { entityType: input.entityType, entityId: input.entityId } },
    select: { id: true, releasedAt: true },
  });
  if (existing && existing.releasedAt === null) {
    throw new VoucherRejectedError('VOUCHER_USER_LIMIT', 'Đơn này đã áp dụng một mã khuyến mãi.');
  }
  await tx.promotion.update({
    where: { id: row.id },
    data: {
      usedCount: { increment: 1 },
      usedBudget: { increment: verdict.discountVnd },
    },
  });
  if (existing) {
    await tx.promotionRedemption.update({
      where: { id: existing.id },
      data: {
        promotionId: row.id,
        userId: input.userId,
        discountVnd: verdict.discountVnd,
        releasedAt: null,
        createdAt: now,
      },
    });
  } else {
    await tx.promotionRedemption.create({
      data: {
        promotionId: row.id,
        userId: input.userId,
        entityType: input.entityType,
        entityId: input.entityId,
        discountVnd: verdict.discountVnd,
      },
    });
  }
  return {
    promotionId: row.id,
    code: row.code,
    discountVnd: verdict.discountVnd,
    sponsor: row.sponsor,
  };
}

/**
 * Cancels a redemption inside the caller's transaction (order cancel) and gives the
 * use and budget back to the campaign. The conditional UPDATE makes replays no-ops.
 */
export async function releaseVoucherInTx(
  tx: Prisma.TransactionClient,
  input: ReleaseVoucherInput,
  now: Date = new Date(),
): Promise<boolean> {
  const released = await tx.$queryRaw<{ promotionId: string; discountVnd: number }[]>`
    UPDATE "promotion_redemptions" SET "releasedAt" = ${now}
    WHERE "entityType" = ${input.entityType}::"PromotionRedemptionEntity"
      AND "entityId" = ${input.entityId}::uuid
      AND "releasedAt" IS NULL
    RETURNING "promotionId", "discountVnd"`;
  const row = released[0];
  if (!row) {
    return false;
  }
  await tx.$executeRaw`
    UPDATE "promotions"
    SET "usedCount" = GREATEST("usedCount" - 1, 0),
        "usedBudget" = GREATEST("usedBudget" - ${row.discountVnd}, 0),
        "updatedAt" = ${now}
    WHERE "id" = ${row.promotionId}::uuid`;
  return true;
}
