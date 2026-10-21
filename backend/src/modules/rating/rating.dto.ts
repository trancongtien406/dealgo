import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
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
