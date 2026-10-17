import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { PARTNER_APPLICATION_ROLES } from './partner.constants.js';

export class PartnerDocumentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  label!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200_000)
  contentBase64?: string;
}

export class SubmitPartnerApplicationDto {
  @IsIn(PARTNER_APPLICATION_ROLES)
  role!: 'DRIVER' | 'MERCHANT';

  @IsObject()
  metadata!: Record<string, unknown>;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => PartnerDocumentDto)
  @ArrayMaxSize(10)
  documents?: PartnerDocumentDto[];
}

export class RejectPartnerApplicationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;
}

export class OpsPartnerApplicationQueryDto {
  @IsOptional()
  @IsIn(['SUBMITTED', 'APPROVED', 'REJECTED', 'DRAFT'])
  status?: 'SUBMITTED' | 'APPROVED' | 'REJECTED' | 'DRAFT';

  @IsOptional()
  @IsIn(['DRIVER', 'MERCHANT'])
  role?: 'DRIVER' | 'MERCHANT';

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
  q?: string;
}
