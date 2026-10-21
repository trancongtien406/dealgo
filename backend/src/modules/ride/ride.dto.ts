import { Type } from 'class-transformer';
import {
  IsDefined,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  Matches,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class GeoPointDto {
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  label!: string;
}

export class CreateRideDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  offeredFareVnd!: number;
}

export class QuoteRideDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;
}

export class CreateOfferDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountVnd!: number;
}

export class StartTripDto {
  /** DEC-PROD-017: the 4-digit code the customer reads out at pickup. */
  @IsString()
  @Matches(/^\d{4}$/, { message: 'pickupCode must be 4 digits' })
  pickupCode!: string;
}

export class SelectOfferDto {
  @IsUUID()
  offerId!: string;

  /** DEC-PROD-024: optional voucher, redeemed atomically with the selection on the agreed fare. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  @Matches(/^[A-Za-z0-9_-]+$/)
  voucherCode?: string;
}

export class RidePageQueryDto {
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
  status?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  zone?: string;

  @IsOptional()
  @IsString()
  /** Accepted for Admin UI compat; Ride has no serviceType column — ignored server-side. */
  serviceType?: string;
}

export class OpsInterveneDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
