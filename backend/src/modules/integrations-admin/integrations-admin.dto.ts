import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

class ReasonDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

/** Omitted = unchanged; null or '' = clear the Admin value (env default applies). */
export class PutEmailSettingsDto extends ReasonDto {
  @IsOptional() @IsString() @MaxLength(20) provider?: string | null;
  @IsOptional() @IsString() @MaxLength(100) fromName?: string | null;
  @IsOptional() @IsString() @MaxLength(254) fromAddress?: string | null;
  @IsOptional() @IsString() @MaxLength(253) smtpHost?: string | null;
  @IsOptional() @IsString() @MaxLength(5) smtpPort?: string | null;
  @IsOptional() @IsString() @MaxLength(254) smtpUser?: string | null;
  @IsOptional() @IsString() @MaxLength(5) smtpSecure?: string | null;
  @IsOptional() @IsString() @MaxLength(30) sesRegion?: string | null;
  @IsOptional() @IsString() @MaxLength(64) sesConfigurationSet?: string | null;
  @IsOptional() @IsString() @MaxLength(256) sesSnsTopicArn?: string | null;
  @IsOptional() @IsString() @MaxLength(256) smtpPassword?: string | null;
  @IsOptional() @IsString() @MaxLength(128) sesAccessKeyId?: string | null;
  @IsOptional() @IsString() @MaxLength(256) sesSecretAccessKey?: string | null;
}

export class TestEmailDto extends ReasonDto {
  @IsString()
  @MaxLength(254)
  to!: string;
}

export class PutMapKeysDto extends ReasonDto {
  @IsOptional() @IsString() @MaxLength(512) mapboxPublicToken?: string | null;
  @IsOptional() @IsString() @MaxLength(512) mapboxServerToken?: string | null;
  @IsOptional() @IsString() @MaxLength(256) googleMapsApiKey?: string | null;
}

export class TestMapKeysDto extends ReasonDto {}
