import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export const FAQ_STATUSES = ['DRAFT', 'PUBLISHED', 'ARCHIVED'] as const;
export const FAQ_CATEGORIES = ['POLICY', 'OPS', 'PRODUCT', 'TECH'] as const;
export const FAQ_AUDIENCES = ['INTERNAL', 'CUSTOMER', 'DRIVER', 'MERCHANT'] as const;
export const HELP_FAQ_AUDIENCES = ['CUSTOMER', 'DRIVER', 'MERCHANT'] as const;

export class HelpFaqQueryDto {
  @IsOptional()
  @IsIn(HELP_FAQ_AUDIENCES)
  audience?: (typeof HELP_FAQ_AUDIENCES)[number];
}

export class CreateOpsFaqDto {
  @IsOptional()
  @IsString()
  @MaxLength(16)
  openId?: string | null;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  question!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(20_000)
  suggestedAnswer!: string;

  @IsIn(FAQ_CATEGORIES)
  category!: (typeof FAQ_CATEGORIES)[number];

  @IsOptional()
  @IsIn(FAQ_AUDIENCES)
  audience?: (typeof FAQ_AUDIENCES)[number];

  @IsOptional()
  @IsIn(FAQ_STATUSES)
  status?: (typeof FAQ_STATUSES)[number];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class PatchOpsFaqDto {
  @IsOptional()
  @IsString()
  @MaxLength(16)
  openId?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  question?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(20_000)
  suggestedAnswer?: string;

  @IsOptional()
  @IsIn(FAQ_STATUSES)
  status?: (typeof FAQ_STATUSES)[number];

  @IsOptional()
  @IsIn(FAQ_CATEGORIES)
  category?: (typeof FAQ_CATEGORIES)[number];

  @IsOptional()
  @IsIn(FAQ_AUDIENCES)
  audience?: (typeof FAQ_AUDIENCES)[number];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class ListOpsFaqQueryDto {
  @IsOptional()
  @IsIn(FAQ_STATUSES)
  status?: (typeof FAQ_STATUSES)[number];
}
