import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  MinLength,
  Min,
} from 'class-validator';
import {
  RATING_SUBJECT_TYPES,
  RATING_TAGS,
  type RatingSubjectType,
  type RatingTag,
} from './rating.constants.js';

export class SubmitRatingDto {
  @IsIn(RATING_SUBJECT_TYPES)
  subjectType!: RatingSubjectType;

  @IsUUID()
  subjectId!: string;

  /** Required when a driver handled the ride/order. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  driverStars?: number;

  /** Food orders only, required there. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  storeStars?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsIn(RATING_TAGS, { each: true })
  tags?: RatingTag[];

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(500)
  comment?: string;
}

export class RatingSubjectParamsDto {
  @IsIn(RATING_SUBJECT_TYPES)
  subjectType!: RatingSubjectType;

  @IsUUID()
  subjectId!: string;
}

const MAX_STORE_IDS = 50;

export class StoreRatingQueryDto {
  /** Comma-separated store ids (max 50). */
  @Transform(({ value }) =>
    typeof value === 'string'
      ? value
          .split(',')
          .map((part) => part.trim())
          .filter((part) => part.length > 0)
      : value,
  )
  @IsArray()
  @ArrayMaxSize(MAX_STORE_IDS)
  @IsUUID('all', { each: true })
  ids!: string[];
}

export class StoreIdParamsDto {
  @IsUUID()
  storeId!: string;
}

export class StoreReviewsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  page?: number;

  /** Only reviews with exactly this many stars. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  stars?: number;
}

export class RatingIdParamsDto {
  @IsUUID()
  id!: string;
}

export class MerchantReviewsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;
}

export class ReplyReviewDto {
  /** Empty or omitted clears the reply. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  text?: string;
}

export class OpsReviewsQueryDto {
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
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsIn(['VISIBLE', 'HIDDEN'])
  visibility?: 'VISIBLE' | 'HIDDEN';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  maxStars?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;
}

export class SetReviewHiddenDto {
  @IsBoolean()
  hidden!: boolean;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
