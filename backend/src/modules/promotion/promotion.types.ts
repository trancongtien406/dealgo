export type DiscountType = 'FIXED_AMOUNT' | 'PERCENTAGE' | 'DELIVERY_DISCOUNT';

export type PromotionStatus =
  | 'ACTIVE'
  | 'SCHEDULED'
  | 'PAUSED'
  | 'ENDED'
  | 'DRAFT'
  | 'CANCELLED';

export type PromotionServiceType = 'ALL' | 'RIDE' | 'FOOD';

export type PromotionAudience = 'ALL' | 'CUSTOMER' | 'DRIVER' | 'MERCHANT';

export type PromotionSponsor = 'PLATFORM' | 'MERCHANT' | 'SHARED';

export interface PromotionCampaign {
  id: string;
  code: string;
  name: string;
  description: string;
  serviceType: PromotionServiceType;
  discountType: DiscountType;
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  totalBudget: number;
  usedBudget: number;
  usageLimit: number;
  usedCount: number;
  userLimit: number;
  targetAudience: PromotionAudience;
  status: PromotionStatus;
  startDate: string;
  endDate: string;
  sponsor: PromotionSponsor;
  /** Set when a merchant created the offer for its own store (FOOD only, MERCHANT-funded). */
  storeId?: string | null;
  /** Store name for ops lists; absent outside them. */
  storeName?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PromotionKpiSummary {
  totalCampaigns: number;
  activeCount: number;
  scheduledCount: number;
  endedCount: number;
  totalBudgetCommitted: number;
  totalBudgetSpent: number;
  totalRedemptions: number;
}

export interface ValidatePromotionInput {
  voucherCode: string;
  serviceType: 'RIDE' | 'FOOD';
  orderAmount: number;
  deliveryFee?: number;
  customerId?: string;
  storeId?: string;
}

export interface ValidatePromotionResult {
  valid: boolean;
  code: string;
  discountAmount: number;
  finalAmount: number;
  reason?: string;
  /** Machine-readable rejection, e.g. VOUCHER_USER_LIMIT. */
  rejectCode?: string;
  campaign?: {
    id: string;
    name: string;
    discountType: DiscountType;
    discountValue: number;
  };
}
