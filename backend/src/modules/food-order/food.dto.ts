import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

export const FOOD_STORE_SORT_BY = ['name', 'createdAt', 'distance'] as const;
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

export class FoodLineDto {
  @IsUUID()
  itemId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20)
  quantity!: number;
}

export class PlaceFoodOrderDto {
  @IsUUID()
  storeId!: string;

  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => FoodLineDto)
  items!: FoodLineDto[];

  @ValidateNested()
  @Type(() => FoodDropoffDto)
  dropoff!: FoodDropoffDto;

  /** Ignored — server quotes delivery fare from distance within FOOD_MIN/MAX. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  deliveryFareVnd?: number;
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
  @IsBoolean()
  available?: boolean;
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
}

export class SetFoodItemAvailabilityDto {
  @IsBoolean()
  available!: boolean;
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

  @ValidateIf((query: ListFoodStoresQueryDto) => query.lng !== undefined || query.lat !== undefined)
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat?: number;

  @ValidateIf((query: ListFoodStoresQueryDto) => query.lat !== undefined || query.lng !== undefined)
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng?: number;

  @IsOptional()
  @IsIn(FOOD_STORE_SORT_BY)
  sort_by?: FoodStoreSortBy;
}

export class OpsPageQueryDto {
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
}

export class OpsCatalogModerationQueryDto {
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

export class OpsCatalogCategoriesQueryDto {
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
  q?: string;
}

export {
  OpsPageQueryDto as FoodOrderOpsPageQueryDto,
  OpsInterveneDto as FoodOrderInterveneDto,
};

