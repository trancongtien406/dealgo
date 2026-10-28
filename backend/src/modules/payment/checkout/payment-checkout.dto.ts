import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { PAYMENT_METHOD_CODES, PAYMENT_SERVICES } from '../../../platform/settings/payment-method-registry.js';

export class PaymentMethodsQueryDto {
  @IsIn(PAYMENT_SERVICES as unknown as string[])
  service!: (typeof PAYMENT_SERVICES)[number];
}

export class StartPaymentDto {
  @IsIn(PAYMENT_METHOD_CODES as unknown as string[])
  methodCode!: (typeof PAYMENT_METHOD_CODES)[number];
}

class ServiceFlagsDto {
  @IsOptional() @IsBoolean() BIKE?: boolean;
  @IsOptional() @IsBoolean() CAR?: boolean;
  @IsOptional() @IsBoolean() FOOD?: boolean;
}

class PaymentMethodPatchDto {
  @IsIn(PAYMENT_METHOD_CODES as unknown as string[])
  code!: (typeof PAYMENT_METHOD_CODES)[number];

  @IsOptional()
  @ValidateNested()
  @Type(() => ServiceFlagsDto)
  services?: ServiceFlagsDto;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(999)
  sortOrder?: number;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  unsupportedReason?: string | null;
}

export class PatchPaymentMethodsDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => PaymentMethodPatchDto)
  methods?: PaymentMethodPatchDto[];

  @IsOptional()
  @IsBoolean()
  walletEnabled?: boolean;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class RefundIntentDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountVnd?: number;

  @IsString()
  @MinLength(3)
  @MaxLength(200)
  reason!: string;
}

export class OpsIntentsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @IsOptional()
  @IsIn(['CREATED', 'PENDING_REDIRECT', 'CAPTURED', 'FAILED', 'EXPIRED', 'REFUND_PENDING', 'REFUNDED'])
  status?: 'CREATED' | 'PENDING_REDIRECT' | 'CAPTURED' | 'FAILED' | 'EXPIRED' | 'REFUND_PENDING' | 'REFUNDED';
}
