import { PAYMENT_METHOD_CODES } from '../../platform/settings/payment-method-registry.js';
import { Transform, Type } from 'class-transformer';
import {
  IsDefined,
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Matches,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

import { LAST_ORDER_MINUTES, MAX_STORE_CLOSURES } from './store-schedule.js';
import {
  BUSY_EXTRA_MINUTES,
  MAX_ACTIVE_ORDERS_LIMIT,
  PREP_MINUTES_MAX,
  PREP_MINUTES_MIN,
  STORE_ACCEPT_MODES,
  type StoreAcceptMode,
} from './store-accept.js';
import {
  STORE_RESUME_MINUTES,
  STORE_SERVICE_MODES,
  type StoreServiceMode,
} from './store-service-mode.js';
import {
  FOOD_DRIVER_RELEASE_REASONS,
  FOOD_REJECT_NOTE_MAX,
  FOOD_REJECT_REASONS,
  type FoodDriverReleaseReason,
  type FoodRejectReason,
  FOOD_FAIL_REASONS,
  FOOD_FAIL_NOTE_MAX,
  type FoodFailReason,
  FOOD_ORDER_CHANGE_REASONS,
  type FoodOrderChangeReason,
} from './food.constants.js';
import { OpsDateRangeQueryDto } from '../operations/ops-date-window.js';

export const FOOD_STORE_SORT_BY = [
  'name',
  'createdAt',
  'distance',
  'rating',
] as const;
export type FoodStoreSortBy = (typeof FOOD_STORE_SORT_BY)[number];

export const FOOD_STORE_BROWSE_MAX_LIMIT = 100;

export class FoodDropoffDto {
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  label!: string;
}

export class QuoteFoodDeliveryDto {
  @IsUUID()
  storeId!: string;

  @IsDefined()
  @ValidateNested()
  @Type(() => FoodDropoffDto)
  dropoff!: FoodDropoffDto;
}

export class FoodLineDto {
  @IsUUID()
  itemId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20)
  quantity!: number;

  /** Chosen option ids; validated against the item's groups and priced server-side. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('all', { each: true })
  optionIds?: string[];

  /** Customer note for this line ("ít cay, không hành"); blank = none. */
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class FoodOptionDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  priceDeltaVnd!: number;

  @IsOptional()
  @IsBoolean()
  available?: boolean;

  /** DEC-PROD-042 — max times this option may be chosen on one line (1–20). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20)
  maxQuantity?: number;
}

export class FoodOptionGroupDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(20)
  minSelect!: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20)
  maxSelect!: number;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => FoodOptionDto)
  options!: FoodOptionDto[];
}

/** Full replacement of a dish's option groups (send [] to remove all). */
export class ReplaceFoodItemOptionsDto {
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => FoodOptionGroupDto)
  groups!: FoodOptionGroupDto[];
}

export class PlaceFoodOrderDto {
  @IsUUID()
  storeId!: string;

  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => FoodLineDto)
  items!: FoodLineDto[];

  @IsDefined()
  @ValidateNested()
  @Type(() => FoodDropoffDto)
  dropoff!: FoodDropoffDto;

  /** Ignored — server quotes delivery fare from distance within FOOD_MIN/MAX. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  deliveryFareVnd?: number;

  /**
   * Customer's delivery-fee offer (default = server suggestion). Must be within
   * [floor, FOOD_MAX_DELIVERY_VND] and a FOOD_FARE_STEP_VND multiple; drivers accept or counter.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10_000_000)
  deliveryOfferVnd?: number;

  /** Optional voucher; re-validated and redeemed atomically with the order. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  @Matches(/^[A-Za-z0-9_-]+$/)
  voucherCode?: string;

  /** Registry payment method code (default CASH); must be enabled for FOOD. */
  @IsOptional()
  @IsIn(PAYMENT_METHOD_CODES as unknown as string[])
  paymentMethod?: (typeof PAYMENT_METHOD_CODES)[number];

  /** Customer note for the store / driver; blank = none. */
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(300)
  note?: string;

  /** Cutlery requested with this order (server default true). */
  @IsOptional()
  @IsBoolean()
  utensils?: boolean;
}

export class CreateFoodItemDto {
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  name!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2_147_483_647)
  priceVnd!: number;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2_147_483_647)
  originalPriceVnd?: number | null;

  @IsOptional()
  @IsBoolean()
  available?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(240)
  prepMinutes?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  imageUrl?: string | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(36)
  menuCategoryId?: string | null;
}

export class UpdateFoodItemDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  name?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2_147_483_647)
  priceVnd?: number;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2_147_483_647)
  originalPriceVnd?: number | null;

  @IsOptional()
  @IsBoolean()
  available?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(240)
  prepMinutes?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  imageUrl?: string | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(36)
  menuCategoryId?: string | null;
}

export class UpsertMenuCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  description?: string | null;
}

export class ReorderMenuCategoriesDto {
  @IsString({ each: true })
  orderedIds!: string[];
}

export class MerchantHistoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  tab?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

  @IsOptional()
  @IsString()
  from?: string;

  @IsOptional()
  @IsString()
  to?: string;
}

/** Why the assigned driver hands an order back before pickup. */
export class ReleaseFoodOrderDto {
  @IsIn(FOOD_DRIVER_RELEASE_REASONS)
  reasonCode!: FoodDriverReleaseReason;
}

/** Failure report after pickup. */
export class FailFoodOrderDto {
  @IsIn(FOOD_FAIL_REASONS)
  reasonCode!: FoodFailReason;

  /** Required when reasonCode is OTHER. */
  @IsOptional()
  @IsString()
  @MaxLength(FOOD_FAIL_NOTE_MAX)
  note?: string;
}

export class RejectFoodOrderDto {
  @IsIn(FOOD_REJECT_REASONS)
  reasonCode!: FoodRejectReason;

  /** Shown to the customer; required when reasonCode is OTHER. */
  @IsOptional()
  @IsString()
  @MaxLength(FOOD_REJECT_NOTE_MAX)
  note?: string;
}

/** One edited order line. */
export class FoodOrderChangeLineDto {
  @IsUUID()
  lineId!: string;

  /** Lower than the ordered quantity; 0 removes the line (out of stock). */
  @IsInt()
  @Min(0)
  @Max(99)
  toQuantity!: number;
}

/** Merchant edits a PLACED/PREPARING order; the customer must confirm. */
export class ProposeFoodOrderChangeDto {
  @IsIn(FOOD_ORDER_CHANGE_REASONS)
  reasonCode!: FoodOrderChangeReason;

  @IsOptional()
  @IsString()
  @MaxLength(FOOD_REJECT_NOTE_MAX)
  note?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => FoodOrderChangeLineDto)
  lines!: FoodOrderChangeLineDto[];
}

export class SetFoodItemAvailabilityDto {
  @IsBoolean()
  available!: boolean;
}

/**
 * M030 (DEC-PROD-045): the merchant renames the store shown to customers;
 * DEC-PROD-067: and/or picks its category (FoodCategory.code, null clears).
 * At least one field is required.
 */
export class UpdateStoreProfileDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(64)
  category?: string | null;

  /** Smallest food subtotal (VND) the store accepts; 0 = none. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10_000_000)
  minOrderVnd?: number;

  /** "About the store" text; '' or null clears it. */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim() || null : value,
  )
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(500)
  description?: string | null;
}

export class UpdateStoreLocationDto {
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng!: number;

  /** Street address shown to drivers on ready jobs. Send null to clear. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  addressLabel?: string | null;
}

export class StoreHourDto {
  /** 1 = Monday … 7 = Sunday. A weekday left out is closed. */
  @IsInt()
  @Min(1)
  @Max(7)
  weekday!: number;

  @Matches(/^([01]\d|2[0-4]):[0-5]\d$/)
  opensAt!: string;

  /** Same day; use 24:00 for midnight. Overnight ranges are not supported. */
  @Matches(/^([01]\d|2[0-4]):[0-5]\d$/)
  closesAt!: string;
}

export class StoreClosureDto {
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  note?: string | null;
}

/** M023 / DEC-PROD-027 — replaces the whole schedule. */
export class UpdateStoreHoursDto {
  @IsArray()
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => StoreHourDto)
  weekly!: StoreHourDto[];

  @IsArray()
  @ArrayMaxSize(MAX_STORE_CLOSURES)
  @ValidateNested({ each: true })
  @Type(() => StoreClosureDto)
  closures!: StoreClosureDto[];

  @IsIn(LAST_ORDER_MINUTES)
  lastOrderMinutes!: number;
}

export class UpdateStoreServiceModeDto {
  /** M024: OPEN takes orders, BUSY takes orders with a longer prep note, PAUSED blocks new orders. */
  @IsIn(STORE_SERVICE_MODES)
  mode!: StoreServiceMode;

  /** Auto-resume to OPEN after 30/60/120 minutes; omit or null = manual. Ignored for OPEN. */
  @IsOptional()
  @IsIn(STORE_RESUME_MINUTES)
  resumeAfterMinutes?: number | null;

  /** M024 BUSY: extra prep minutes added to the customer estimate; omit to keep the saved value. */
  @IsOptional()
  @IsIn(BUSY_EXTRA_MINUTES)
  busyExtraMinutes?: number;
}

/** M022 order-acceptance settings (DEC-PROD-028). */
export class UpdateStoreAcceptSettingsDto {
  @IsIn(STORE_ACCEPT_MODES)
  acceptMode!: StoreAcceptMode;

  /** Max orders in PLACED+PREPARING; null = no cap. */
  @ValidateIf((_dto, value) => value !== null)
  @IsInt()
  @Min(1)
  @Max(MAX_ACTIVE_ORDERS_LIMIT)
  maxActiveOrders!: number | null;

  @IsInt()
  @Min(PREP_MINUTES_MIN)
  @Max(PREP_MINUTES_MAX)
  defaultPrepMinutes!: number;

  /** Stop taking orders this many minutes before closing; shared with M023. */
  @IsIn(LAST_ORDER_MINUTES)
  lastOrderMinutes!: number;
}

export class OpsInterveneDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class ListFoodStoresQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(FOOD_STORE_BROWSE_MAX_LIMIT)
  limit?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  category?: string;

  @ValidateIf(
    (query: ListFoodStoresQueryDto) =>
      query.lng !== undefined || query.lat !== undefined,
  )
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat?: number;

  @ValidateIf(
    (query: ListFoodStoresQueryDto) =>
      query.lat !== undefined || query.lng !== undefined,
  )
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng?: number;

  @IsOptional()
  @IsIn(FOOD_STORE_SORT_BY)
  sort_by?: FoodStoreSortBy;

  /** Only stores within this many km (needs lat/lng; capped by FOOD_BROWSE_RADIUS_KM). */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(0.5)
  @Max(50)
  max_km?: number;
}

/**
 * Optional customer position on the store detail, so the hero's "from" fee is
 * quoted the same way as the browse card (same lat/lng pair rules).
 */
export class StoreDetailQueryDto {
  @ValidateIf(
    (query: StoreDetailQueryDto) =>
      query.lng !== undefined || query.lat !== undefined,
  )
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat?: number;

  @ValidateIf(
    (query: StoreDetailQueryDto) =>
      query.lat !== undefined || query.lng !== undefined,
  )
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng?: number;
}

export const FOOD_SEARCH_MAX_LIMIT = 20;

/** Dish search keeps the browse filters; the dish keyword is `q` (the browse keyword stays `search`). */
export class SearchFoodDto extends ListFoodStoresQueryDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  q!: string;

  /** Search pages cap at 20 rather than the browse cap; the initializer lets TS accept the narrower redeclaration. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(FOOD_SEARCH_MAX_LIMIT)
  limit?: number = undefined;
}

export class SuggestFoodItemsDto {
  /** Item ids to leave out, comma-separated in the query string; their categories are skipped too. */
  @IsOptional()
  @Transform(({ value }) => {
    const list: unknown = Array.isArray(value)
      ? value
      : typeof value === 'string'
        ? value.split(',')
        : value;
    return Array.isArray(list)
      ? list
          .map((entry) => (typeof entry === 'string' ? entry.trim() : entry))
          .filter(Boolean)
      : list;
  })
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  exclude?: string[];
}

export class OpsPageQueryDto extends OpsDateRangeQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  status?: string;

  /** Comma-separated Nest food statuses, e.g. READY,ASSIGNED,PICKED_UP */
  @IsOptional()
  @IsString()
  statuses?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  store?: string;

  @IsOptional()
  @IsString()
  payment?: string;

  @IsOptional()
  @IsString()
  zone?: string;

  @IsOptional()
  @IsString()
  sale?: string;

  @IsOptional()
  @IsString()
  region?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  kyb?: string;

  /** MISSING lists stores that cannot take delivery orders (no coordinates). */
  @IsOptional()
  @IsIn(['ALL', 'MISSING'])
  location?: string;
}

export class OpsCatalogModerationQueryDto extends OpsDateRangeQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  store?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  status?: string;
}

export {
  OpsPageQueryDto as FoodOrderOpsPageQueryDto,
  OpsInterveneDto as FoodOrderInterveneDto,
};

export class MerchantStatsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  days?: number;
}

const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

/** ICT day range for merchant statements (inclusive). */
export class MerchantStatementQueryDto {
  @IsOptional()
  @Matches(DAY_KEY)
  from?: string;

  @IsOptional()
  @Matches(DAY_KEY)
  to?: string;
}

export class RecordMerchantSettlementDto {
  @Matches(DAY_KEY)
  from!: string;

  @Matches(DAY_KEY)
  to!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

/** DEC-PROD-036: the merchant's handover code, required when FOOD_HANDOVER_CODE_REQUIRED. */
export class PickupFoodOrderDto {
  @IsOptional()
  @Matches(/^\d{4}$/, { message: 'handoverCode must be 4 digits' })
  handoverCode?: string;
}

/** DEC-PROD-036: the customer's delivery code, required when FOOD_DELIVERY_CODE_REQUIRED. */
export class DeliverFoodOrderDto {
  @IsOptional()
  @Matches(/^\d{4}$/, { message: 'deliveryCode must be 4 digits' })
  deliveryCode?: string;
}

/** Driver counter-offer or customer raise of the delivery fee (VND). */
export class FoodDeliveryAmountDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10_000_000)
  amountVnd!: number;
}
