import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsISO8601, IsObject, IsOptional, IsString, MaxLength, MinLength, ValidateIf } from 'class-validator';
import { PUBLIC_PAGE_LOCALES } from './public-pages.types.js';

export class PublicPageQueryDto {
  @ApiPropertyOptional({ enum: PUBLIC_PAGE_LOCALES })
  @IsOptional()
  @IsIn(PUBLIC_PAGE_LOCALES as unknown as string[])
  locale?: string;
}

export class SavePublicPageDraftDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title!: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsString()
  @MaxLength(500)
  summary?: string | null;

  @ApiPropertyOptional({ nullable: true, description: 'ISO date (effective date)' })
  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsISO8601()
  effectiveAt?: string | null;

  @ApiProperty({ description: 'Legal: {badge, sections[]}; support: support config' })
  @IsObject()
  content!: Record<string, unknown>;
}

export class PublishPublicPageDto {
  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
