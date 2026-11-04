import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import type { DriverTopUpStatusName } from './driver-credit.repository.js';

export const DRIVER_TOP_UP_STATUSES: readonly DriverTopUpStatusName[] = [
  'PENDING',
  'PAID',
  'EXPIRED',
  'CANCELLED',
  'REFUND_PENDING',
  'REFUNDED',
  'FAILED',
];

export class CreateDriverTopUpDto {
  @ApiProperty({ description: 'Amount to prepay in VND', minimum: 1000, maximum: 50_000_000 })
  @IsInt()
  @Min(1000)
  @Max(50_000_000)
  amountVnd!: number;
}

export class DriverTopUpListQueryDto {
  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class OpsDriverTopUpQueryDto {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID('all')
  driverId?: string;

  @ApiPropertyOptional({ enum: DRIVER_TOP_UP_STATUSES })
  @IsOptional()
  @IsIn(DRIVER_TOP_UP_STATUSES)
  status?: DriverTopUpStatusName;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

/** Ops records the manual bank transfer that returns unused credit to the driver. */
export class OpsDriverCreditRefundDto {
  @ApiProperty({ minLength: 5, maxLength: 500 })
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  reason!: string;

  @ApiProperty({ description: 'Bank transfer reference / transaction id', minLength: 3, maxLength: 120 })
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  bankRef!: string;
}
