import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

const REGION_STATUSES = ['ACTIVE', 'PLANNED'] as const;
export type ServiceRegionStatusInput = (typeof REGION_STATUSES)[number];

export class ServiceRegionBBoxDto {
  @IsNumber()
  minLat!: number;

  @IsNumber()
  maxLat!: number;

  @IsNumber()
  minLng!: number;

  @IsNumber()
  maxLng!: number;
}

export class ListOpsZonesQueryDto {
  /** Default ACTIVE (pilot view). ALL / PLANNED for the zone management table. */
  @IsOptional()
  @IsIn(['ACTIVE', 'PLANNED', 'ALL'])
  status?: 'ACTIVE' | 'PLANNED' | 'ALL';
}

export class CreateOpsZoneDto {
  @IsString()
  @Matches(/^[A-Za-z][A-Za-z0-9]{1,7}$/, {
    message: 'code must be 2-8 letters/digits starting with a letter',
  })
  code!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  label!: string;

  @IsNumber()
  centerLat!: number;

  @IsNumber()
  centerLng!: number;

  @ValidateNested()
  @Type(() => ServiceRegionBBoxDto)
  bbox!: ServiceRegionBBoxDto;

  @IsOptional()
  @IsIn(REGION_STATUSES)
  status?: ServiceRegionStatusInput;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class PatchOpsZoneDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  label?: string;

  @IsOptional()
  @IsNumber()
  centerLat?: number;

  @IsOptional()
  @IsNumber()
  centerLng?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => ServiceRegionBBoxDto)
  bbox?: ServiceRegionBBoxDto;

  @IsOptional()
  @IsIn(REGION_STATUSES)
  status?: ServiceRegionStatusInput;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
