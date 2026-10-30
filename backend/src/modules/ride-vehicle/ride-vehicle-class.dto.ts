import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class PatchRideVehicleClassDto {
  /** Why the class changed; stored in the ops audit log. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  /** DEC-PROD-071: class can be booked for parcel delivery. */
  @IsOptional()
  @IsBoolean()
  parcelEnabled?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(16)
  seats?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  baseFareVnd?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  perKmVnd?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  perMinuteVnd?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  minFareVnd?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  maxFareVnd?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(5)
  @Max(120)
  assumedSpeedKmh?: number;
}

export class UploadRideVehicleClassImageDto {
  @ValidateIf((body: UploadRideVehicleClassImageDto) => !body.dataUrl)
  @IsString()
  @MinLength(8)
  @MaxLength(2_700_000)
  contentBase64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  @ValidateIf((body: UploadRideVehicleClassImageDto) => !body.contentBase64)
  @IsString()
  @MinLength(20)
  @MaxLength(2_700_000)
  dataUrl?: string;
}

export class PutRideZoneTariffDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(100_000)
  perKmVnd!: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  minFareVnd!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
