import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
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
import {
  HOME_BANNER_AUDIENCES,
  HOME_BANNER_EVENT_TYPES,
  HOME_BANNER_SERVICES,
  type HomeBannerAudience,
  type HomeBannerEventType,
  type HomeBannerServiceScope,
} from './home-banner.js';

export class CreateHomeBannerDto {
  /** In-app path (/customer/shop), dealgo:// link or https:// URL. */
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(500)
  ctaUrl?: string | null;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(3)
  @IsIn(HOME_BANNER_AUDIENCES, { each: true })
  audiences!: HomeBannerAudience[];

  @IsOptional()
  @IsIn(HOME_BANNER_SERVICES)
  service?: HomeBannerServiceScope;

  /** ServiceRegion code; null / omitted = every region. */
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(8)
  regionCode?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsISO8601()
  startsAt?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsISO8601()
  endsAt?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(100_000)
  sortOrder?: number;

  /** Needs an image; create inactive, upload, then activate. */
  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class PatchHomeBannerDto {
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(500)
  ctaUrl?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(3)
  @IsIn(HOME_BANNER_AUDIENCES, { each: true })
  audiences?: HomeBannerAudience[];

  @IsOptional()
  @IsIn(HOME_BANNER_SERVICES)
  service?: HomeBannerServiceScope;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(8)
  regionCode?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsISO8601()
  startsAt?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsISO8601()
  endsAt?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(100_000)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ReorderHomeBannersDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @IsUUID('all', { each: true })
  ids!: string[];
}

export class UploadHomeBannerImageDto {
  @ValidateIf((body: UploadHomeBannerImageDto) => !body.dataUrl)
  @IsString()
  @MinLength(8)
  @MaxLength(2_700_000)
  contentBase64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  @ValidateIf((body: UploadHomeBannerImageDto) => !body.contentBase64)
  @IsString()
  @MinLength(20)
  @MaxLength(2_700_000)
  dataUrl?: string;
}

export class ListPublicHomeBannersQuery {
  @IsIn(HOME_BANNER_AUDIENCES)
  role!: HomeBannerAudience;

  @IsOptional()
  @IsIn(HOME_BANNER_SERVICES)
  service?: HomeBannerServiceScope;

  @IsOptional()
  @IsString()
  @MaxLength(8)
  region?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;
}

export class HomeBannerEventDto {
  @IsUUID()
  bannerId!: string;

  @IsIn(HOME_BANNER_EVENT_TYPES)
  type!: HomeBannerEventType;
}

export class HomeBannerEventsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => HomeBannerEventDto)
  events!: HomeBannerEventDto[];
}
