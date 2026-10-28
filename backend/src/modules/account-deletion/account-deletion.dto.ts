import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';

export class ConfirmAccountDeletionDto {
  @ApiPropertyOptional({ description: '6-digit SMS code when method = PHONE_OTP' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4,8}$/)
  code?: string;

  @ApiPropertyOptional({ description: 'Account password when method = PASSWORD' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  password?: string;

  @ApiPropertyOptional({
    description:
      'WebAuthn assertion (AuthenticationResponseJSON) over start.passkeyOptions when method = PASSKEY',
  })
  @IsOptional()
  @IsObject()
  passkey?: AuthenticationResponseJSON;
}

export class OpsReasonDto {
  @ApiProperty({ minLength: 3, maxLength: 500 })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

/** Partial cash payment between a driver and DealGo, recorded by Ops. */
export class OpsDriverPaymentDto extends OpsReasonDto {
  @ApiProperty({ enum: ['DRIVER_PAID', 'DEALGO_PAID'] })
  @IsIn(['DRIVER_PAID', 'DEALGO_PAID'])
  direction!: 'DRIVER_PAID' | 'DEALGO_PAID';

  @ApiProperty({ minimum: 1000, maximum: 50_000_000 })
  @IsInt()
  @Min(1000)
  @Max(50_000_000)
  amountVnd!: number;
}
