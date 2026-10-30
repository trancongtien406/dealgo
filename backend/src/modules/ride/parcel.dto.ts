import { Type } from 'class-transformer';
import {
  IsDefined,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { PARCEL_SIZE_CODES } from '../../platform/settings/parcel-size-classes.js';
import { PAYMENT_METHOD_CODES } from '../../platform/settings/payment-method-registry.js';
import { GeoPointDto } from './ride.dto.js';

const PHONE = /^\+?[0-9]{8,15}$/;
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** One base64 photo (item / pickup / delivery / return proof). Size limits = admin upload policy. */
export class ParcelPhotoDto {
  @IsIn(IMAGE_TYPES)
  contentType!: string;

  @IsString()
  @MinLength(16)
  @MaxLength(12_000_000)
  contentBase64!: string;
}

export class ParcelContactDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsString()
  @Matches(PHONE)
  phone!: string;
}

export class QuoteParcelDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  pickup!: GeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => GeoPointDto)
  dropoff!: GeoPointDto;

  @IsIn(PARCEL_SIZE_CODES as unknown as string[])
  sizeClass!: (typeof PARCEL_SIZE_CODES)[number];

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(0.1)
  @Max(500)
  weightKg?: number;
}

export class CreateParcelDto extends QuoteParcelDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  offeredFareVnd!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(32)
  @Matches(/^[A-Za-z0-9_]+$/)
  vehicleClassCode!: string;

  @IsDefined()
  @ValidateNested()
  @Type(() => ParcelContactDto)
  sender!: ParcelContactDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => ParcelContactDto)
  recipient!: ParcelContactDto;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  /** RECIPIENT = cash collected at dropoff (CASH only). */
  @IsOptional()
  @IsIn(['SENDER', 'RECIPIENT'])
  payer?: 'SENDER' | 'RECIPIENT';

  @IsOptional()
  @IsIn(PAYMENT_METHOD_CODES as unknown as string[])
  paymentMethod?: (typeof PAYMENT_METHOD_CODES)[number];

  @IsOptional()
  @ValidateNested()
  @Type(() => ParcelPhotoDto)
  itemPhoto?: ParcelPhotoDto;
}

export class ParcelPickupDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => ParcelPhotoDto)
  photo!: ParcelPhotoDto;

  /** Sender's pickup code when PICKUP_CODE_REQUIRED (same rule as Ride). */
  @IsOptional()
  @IsString()
  @Matches(/^[0-9]{4,8}$/)
  pickupCode?: string;
}

export class ParcelDeliverDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => ParcelPhotoDto)
  photo!: ParcelPhotoDto;

  /** Recipient's code; required when PARCEL_RECIPIENT_CODE_REQUIRED. */
  @IsOptional()
  @IsString()
  @Matches(/^[0-9]{4,8}$/)
  recipientCode?: string;
}

export const PARCEL_FAIL_REASONS = ['RECIPIENT_UNREACHABLE', 'RECIPIENT_REFUSED', 'ADDRESS_WRONG', 'ITEM_DAMAGED', 'OTHER'] as const;

export class ParcelFailDto {
  @IsIn(PARCEL_FAIL_REASONS as unknown as string[])
  reason!: (typeof PARCEL_FAIL_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class ParcelReturnedDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => ParcelPhotoDto)
  photo!: ParcelPhotoDto;
}

export class OpsParcelQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @IsIn(['PENDING', 'DELIVERED', 'RETURNING', 'RETURNED'])
  outcome?: 'PENDING' | 'DELIVERED' | 'RETURNING' | 'RETURNED';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;
}
