import { Type } from 'class-transformer';
import {
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
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
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  offeredFareVnd!: number;
}

export class CreateOfferDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountVnd!: number;
}

export class SelectOfferDto {
  @IsUUID()
  offerId!: string;
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
