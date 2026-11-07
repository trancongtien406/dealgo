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

export const MERCHANT_REVIEW_REPLY_FILTERS = ['REPLIED', 'UNREPLIED'] as const;
export type MerchantReviewReplyFilter = (typeof MERCHANT_REVIEW_REPLY_FILTERS)[number];

export const MERCHANT_REVIEW_VISIBILITY_FILTERS = ['VISIBLE', 'HIDDEN'] as const;
export type MerchantReviewVisibilityFilter = (typeof MERCHANT_REVIEW_VISIBILITY_FILTERS)[number];

export const MERCHANT_REVIEW_SORTS = [
  'NEWEST',
  'OLDEST',
  'LOWEST_STARS',
  'HIGHEST_STARS',
] as const;
export type MerchantReviewSort = (typeof MERCHANT_REVIEW_SORTS)[number];

export class MerchantReviewsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  /** Only reviews with exactly this many stars (1..5). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  stars?: number;

  /** Filter by merchant reply state. */
  @IsOptional()
  @IsIn(MERCHANT_REVIEW_REPLY_FILTERS)
  replied?: MerchantReviewReplyFilter;

  /** When true, only reviews with a non-empty customer text comment. */
  @IsOptional()
  @Transform(({ value }) => {
    if (value === true || value === 'true' || value === '1') return true;
    if (value === false || value === 'false' || value === '0') return false;
    return value;
  })
  @IsBoolean()
  hasComment?: boolean;

  /** Filter by moderation visibility. */
  @IsOptional()
  @IsIn(MERCHANT_REVIEW_VISIBILITY_FILTERS)
  visibility?: MerchantReviewVisibilityFilter;

  /** Filter by a quick-pick rating tag. */
  @IsOptional()
  @IsIn(RATING_TAGS)
  tag?: RatingTag;

  /** Free-text search in customer comment or merchant reply. */
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  /** ISO date/timestamp lower bound (inclusive). */
  @IsOptional()
  @IsString()
  from?: string;

  /** ISO date/timestamp upper bound (inclusive). */
  @IsOptional()
  @IsString()
  to?: string;

  /** Sort order (defaults to NEWEST). */
  @IsOptional()
  @IsIn(MERCHANT_REVIEW_SORTS)
  sort?: MerchantReviewSort;
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
