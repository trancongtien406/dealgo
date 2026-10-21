import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  ALL_PARTNER_DOCUMENT_KINDS,
  ALL_PARTNER_ISSUE_SECTIONS,
  PARTNER_APPLICATION_ROLES,
  PARTNER_MAX_DOCUMENTS_PER_REQUEST,
} from './partner.constants.js';
import { UPLOAD_BASE64_MAX_CHARS } from '../../platform/http/route-body-parsers.js';

export class PartnerDocumentDto {
  @IsIn(ALL_PARTNER_DOCUMENT_KINDS)
  kind!: (typeof ALL_PARTNER_DOCUMENT_KINDS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(160)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  /** Base64 file bytes; size/type limits are admin settings (UPLOAD_MAX_FILE_KB/TYPES). */
  @IsString()
  @MinLength(8)
  @MaxLength(UPLOAD_BASE64_MAX_CHARS)
  contentBase64!: string;
}

export class PartnerReviewIssueDto {
  @IsIn(ALL_PARTNER_ISSUE_SECTIONS)
  section!: (typeof ALL_PARTNER_ISSUE_SECTIONS)[number];

  @IsString()
  @MinLength(1)
  @MaxLength(300)
  note!: string;
}

export class SubmitPartnerApplicationDto {
  @IsIn(PARTNER_APPLICATION_ROLES)
  role!: 'DRIVER' | 'MERCHANT';

  @IsObject()
  metadata!: Record<string, unknown>;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => PartnerDocumentDto)
  @ArrayMaxSize(PARTNER_MAX_DOCUMENTS_PER_REQUEST)
  documents?: PartnerDocumentDto[];
}

export class RejectPartnerApplicationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;

  /** Sections the applicant must fix; empty means a plain rejection. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => PartnerReviewIssueDto)
  issues?: PartnerReviewIssueDto[];
}

export class PartnerDocumentParamsDto {
  @IsUUID()
  id!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(20)
  index!: number;
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
