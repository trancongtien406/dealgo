import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import type {
  DiscountType,
  PromotionAudience,
  PromotionServiceType,
  PromotionSponsor,
  PromotionStatus,
} from './promotion.types.js';

// Amounts are whole VND persisted as PostgreSQL INTEGER.
const MAX_VND = 2_147_483_647;

function upperCase({ value }: { value: unknown }): unknown {
  return typeof value === 'string' ? value.trim().toUpperCase() : value;
}

export class OpsPromotionQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @IsOptional()
  @Transform(upperCase)
  @IsIn(['ALL', 'ACTIVE', 'SCHEDULED', 'PAUSED', 'ENDED', 'DRAFT', 'CANCELLED'])
  status?: PromotionStatus | 'ALL';

  @IsOptional()
  @Transform(upperCase)
  @IsIn(['ALL', 'RIDE', 'FOOD'])
  serviceType?: PromotionServiceType;

  @IsOptional()
  @Transform(upperCase)
  @IsIn(['ALL', 'CUSTOMER', 'DRIVER', 'MERCHANT'])
  audience?: PromotionAudience;
}

export class CreatePromotionBodyDto {
  @IsNotEmpty()
  @IsString()
  @Matches(/^\s*[A-Za-z0-9_-]{3,40}\s*$/)
  code!: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(160)
  name!: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  description!: string;

  @IsNotEmpty()
  @IsIn(['ALL', 'RIDE', 'FOOD'])
  serviceType!: PromotionServiceType;

  @IsNotEmpty()
  @IsIn(['FIXED_AMOUNT', 'PERCENTAGE', 'DELIVERY_DISCOUNT'])
  discountType!: DiscountType;

  @IsInt()
  @Min(1)
  @Max(MAX_VND)
  discountValue!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_VND)
  maxDiscountAmount?: number;

  @IsInt()
  @Min(0)
  @Max(MAX_VND)
  minOrderAmount!: number;

  @IsInt()
  @Min(1000)
  @Max(MAX_VND)
  totalBudget!: number;

  @IsInt()
  @Min(1)
  usageLimit!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  userLimit?: number;

  @IsOptional()
  @IsIn(['ALL', 'CUSTOMER', 'DRIVER', 'MERCHANT'])
  targetAudience?: PromotionAudience;

  @IsISO8601()
  startDate!: string;

  @IsISO8601()
  endDate!: string;

  @IsOptional()
  @IsIn(['PLATFORM', 'MERCHANT', 'SHARED'])
  sponsor?: PromotionSponsor;
}

export class UpdatePromotionStatusDto {
  @IsNotEmpty()
  @IsIn(['ACTIVE', 'SCHEDULED', 'PAUSED', 'ENDED', 'CANCELLED'])
  status!: PromotionStatus;
}

export class ValidateVoucherBodyDto {
  @IsNotEmpty()
  @IsString()
  voucherCode!: string;

  @IsNotEmpty()
  @IsIn(['RIDE', 'FOOD'])
  serviceType!: 'RIDE' | 'FOOD';

  @IsInt()
  @Min(0)
  @Max(MAX_VND)
  orderAmount!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MAX_VND)
  deliveryFee?: number;

  /** Deprecated and ignored: the customer comes from the session. */
  @IsOptional()
  @IsString()
  customerId?: string;

  @IsOptional()
  @IsString()
  storeId?: string;
}

export class AvailableVouchersQueryDto {
  @IsOptional()
  @IsIn(['RIDE', 'FOOD'])
  serviceType?: 'RIDE' | 'FOOD';
}
