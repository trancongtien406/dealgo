import { ArrayNotEmpty, IsArray, IsBoolean, IsIn, IsInt, IsISO8601, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';
import { LEGAL_AUDIENCE_ROLES, LEGAL_CONSENT_SLUGS } from './legal-consent.types.js';

export class PublishLegalVersionDto {
  @IsIn(LEGAL_CONSENT_SLUGS as unknown as string[])
  slug!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  changelog!: string;

  @IsOptional()
  @IsISO8601()
  effectiveAt?: string;

  @IsArray()
  @ArrayNotEmpty()
  @IsIn(LEGAL_AUDIENCE_ROLES as unknown as string[], { each: true })
  audienceRoles!: string[];

  @IsOptional()
  @IsBoolean()
  requiresConsent?: boolean;
}

export class SendLegalEmailDto {
  /** Recipient count the admin saw in the preview; must still match (two-step send). */
  @IsInt()
  @Min(0)
  confirmCount!: number;
}
