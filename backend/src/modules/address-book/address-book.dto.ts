import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { SAVED_ADDRESS_KINDS, type SavedAddressKind } from './address-book.constants.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class CreateSavedAddressDto {
  @IsIn(SAVED_ADDRESS_KINDS)
  kind!: SavedAddressKind;

  @Transform(trim)
  @IsString()
  @Length(1, 60)
  label!: string;

  @Transform(trim)
  @IsString()
  @Length(3, 300)
  addressLine!: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  note?: string | null;

  /** Optional pin; send lat and lng together. */
  @ValidateIf((dto: CreateSavedAddressDto) => dto.lng !== undefined || dto.lat !== undefined)
  @IsLatitude()
  lat?: number;

  @ValidateIf((dto: CreateSavedAddressDto) => dto.lat !== undefined || dto.lng !== undefined)
  @IsLongitude()
  lng?: number;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}

export class UpdateSavedAddressDto {
  @IsOptional()
  @IsIn(SAVED_ADDRESS_KINDS)
  kind?: SavedAddressKind;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  label?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(3, 300)
  addressLine?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  note?: string | null;

  @ValidateIf((dto: UpdateSavedAddressDto) => dto.lng !== undefined || dto.lat !== undefined)
  @IsLatitude()
  lat?: number;

  @ValidateIf((dto: UpdateSavedAddressDto) => dto.lat !== undefined || dto.lng !== undefined)
  @IsLongitude()
  lng?: number;

  /** Only `true` is meaningful: the address becomes the default. */
  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
