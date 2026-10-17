import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export const NOTIFICATION_CHANNELS = ['PUSH', 'SMS', 'EMAIL', 'IN_APP'] as const;
export const NOTIFICATION_AUDIENCES = ['ALL', 'CUSTOMER', 'DRIVER', 'MERCHANT', 'STAFF'] as const;
export const CAMPAIGN_TABS = ['ALL', 'RUNNING', 'SENT', 'PENDING', 'DRAFT'] as const;
export const CMS_KINDS = ['ARTICLE', 'BANNER', 'POLICY'] as const;
export const CMS_STATUSES = ['DRAFT', 'IN_REVIEW', 'PUBLISHED'] as const;

export class ListCampaignsQueryDto {
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
  @MaxLength(120)
  q?: string;

  @IsOptional()
  @IsIn(CAMPAIGN_TABS)
  tab?: (typeof CAMPAIGN_TABS)[number];

  @IsOptional()
  @IsIn(NOTIFICATION_CHANNELS)
  channel?: (typeof NOTIFICATION_CHANNELS)[number];

  @IsOptional()
  @IsIn(NOTIFICATION_AUDIENCES)
  audience?: (typeof NOTIFICATION_AUDIENCES)[number];
}

export class CreateCampaignDto {
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  title!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  body!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(4)
  @IsIn(NOTIFICATION_CHANNELS, { each: true })
  channels!: (typeof NOTIFICATION_CHANNELS)[number][];

  @IsIn(NOTIFICATION_AUDIENCES)
  audience!: (typeof NOTIFICATION_AUDIENCES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(160)
  audienceNote?: string | null;

  @IsOptional()
  @IsBoolean()
  isAutomatic?: boolean;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason?: string;
}

export class UpdateCampaignDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  title?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  body?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(4)
  @IsIn(NOTIFICATION_CHANNELS, { each: true })
  channels?: (typeof NOTIFICATION_CHANNELS)[number][];

  @IsOptional()
  @IsIn(NOTIFICATION_AUDIENCES)
  audience?: (typeof NOTIFICATION_AUDIENCES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(160)
  audienceNote?: string | null;

  @IsOptional()
  @IsBoolean()
  isAutomatic?: boolean;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason?: string;
}

/** Optional note for non-destructive transitions (submit). */
export class OptionalReasonDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason?: string;
}

/** Required reason for approve / reject / cancel (audit + author feedback). */
export class CampaignReasonDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class ListCmsQueryDto {
  @IsOptional()
  @IsIn(CMS_KINDS)
  kind?: (typeof CMS_KINDS)[number];

  @IsOptional()
  @IsIn(CMS_STATUSES)
  status?: (typeof CMS_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;
}

export class CreateCmsDto {
  @IsIn(CMS_KINDS)
  kind!: (typeof CMS_KINDS)[number];

  @IsString()
  @MinLength(3)
  @MaxLength(200)
  title!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(50_000)
  body!: string;

  @IsOptional()
  @IsIn(CMS_STATUSES)
  status?: (typeof CMS_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason?: string;
}

export class PatchCmsDto {
  @IsOptional()
  @IsIn(CMS_KINDS)
  kind?: (typeof CMS_KINDS)[number];

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(50_000)
  body?: string;

  @IsOptional()
  @IsIn(CMS_STATUSES)
  status?: (typeof CMS_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason?: string;
}
