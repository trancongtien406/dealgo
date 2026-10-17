import {
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class QueryPlatformSettingsDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  source?: string;
}

export class PatchPlatformSettingDto {
  @IsString()
  @MinLength(0)
  @MaxLength(4000)
  value!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

