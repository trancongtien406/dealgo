import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateIf,
  ArrayMaxSize,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { UPLOAD_BASE64_MAX_CHARS } from '../../platform/http/route-body-parsers.js';
import {
  SUPPORT_APP_ROLES,
  SUPPORT_PUBLIC_ROLES,
  SUPPORT_TEXT_HARD_MAX,
  SUPPORT_TICKET_CATEGORIES,
  SUPPORT_TICKET_PRIORITIES,
  SUPPORT_TICKET_RELATED_TYPES,
  SUPPORT_TICKET_STATUSES,
} from './support-ticket.constants.js';
import type {
  SupportTicketCategory,
  SupportTicketPriority,
  SupportTicketRelatedType,
  SupportTicketStatus,
} from './support-ticket.repository.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const blankToUndefined = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
};

class PageQueryDto {
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
}

/** Images or PDFs a requester or staff attaches to a message (DEC-PROD-020). */
export const SUPPORT_MAX_ATTACHMENTS = 3;

export class SupportAttachmentDto {
  @IsOptional()
  @IsString()
  @MaxLength(160)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  /** Base64 bytes; per-file size/type from UPLOAD_MAX_FILE_KB / UPLOAD_ALLOWED_TYPES. */
  @IsString()
  @Length(8, UPLOAD_BASE64_MAX_CHARS)
  contentBase64!: string;
}

export class CreateSupportTicketDto {
  @IsIn(SUPPORT_TICKET_CATEGORIES)
  category!: SupportTicketCategory;

  @Transform(trim)
  @IsString()
  @Length(3, 120)
  subject!: string;

  @Transform(trim)
  @IsString()
  @Length(10, SUPPORT_TEXT_HARD_MAX)
  description!: string;

  /** Which app shell the user writes from; defaults to CUSTOMER. */
  @IsOptional()
  @IsIn(SUPPORT_APP_ROLES)
  role?: (typeof SUPPORT_APP_ROLES)[number];

  @ValidateIf((dto: CreateSupportTicketDto) => dto.relatedId !== undefined || dto.relatedType !== undefined)
  @IsIn(SUPPORT_TICKET_RELATED_TYPES)
  relatedType?: SupportTicketRelatedType;

  @ValidateIf((dto: CreateSupportTicketDto) => dto.relatedId !== undefined || dto.relatedType !== undefined)
  @IsUUID()
  relatedId?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(SUPPORT_MAX_ATTACHMENTS)
  @ValidateNested({ each: true })
  @Type(() => SupportAttachmentDto)
  attachments?: SupportAttachmentDto[];
}

export class CreatePublicSupportTicketDto {
  @IsIn(SUPPORT_PUBLIC_ROLES)
  role!: (typeof SUPPORT_PUBLIC_ROLES)[number];

  @IsIn(SUPPORT_TICKET_CATEGORIES)
  category!: SupportTicketCategory;

  @IsOptional()
  @Transform(blankToUndefined)
  @IsString()
  @Length(3, 120)
  subject?: string;

  @Transform(trim)
  @IsString()
  @Length(10, SUPPORT_TEXT_HARD_MAX)
  description!: string;

  /** Phone (VN) or email the team calls/writes back to. */
  @Transform(trim)
  @IsString()
  @Length(5, 120)
  contact!: string;

  @IsOptional()
  @Transform(blankToUndefined)
  @IsString()
  @MaxLength(80)
  contactName?: string;

  /** Free-text booking/order code the visitor sees in their app. */
  @IsOptional()
  @Transform(blankToUndefined)
  @IsString()
  @MaxLength(50)
  externalRef?: string;
}

export class ListMySupportTicketsQueryDto extends PageQueryDto {
  /** ACTIVE = OPEN/IN_PROGRESS, DONE = RESOLVED/CLOSED. */
  @IsOptional()
  @IsIn(['ACTIVE', 'DONE'])
  state?: 'ACTIVE' | 'DONE';
}

export class SupportMessageDto {
  @Transform(trim)
  @IsString()
  @Length(1, SUPPORT_TEXT_HARD_MAX)
  body!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(SUPPORT_MAX_ATTACHMENTS)
  @ValidateNested({ each: true })
  @Type(() => SupportAttachmentDto)
  attachments?: SupportAttachmentDto[];
}

export class ListOpsSupportTicketsQueryDto extends PageQueryDto {
  @IsOptional()
  @IsIn(SUPPORT_TICKET_STATUSES)
  status?: SupportTicketStatus;

  @IsOptional()
  @IsIn(SUPPORT_TICKET_CATEGORIES)
  category?: SupportTicketCategory;

  @IsOptional()
  @IsIn(['APP', 'WEB'])
  channel?: 'APP' | 'WEB';

  @IsOptional()
  @Transform(blankToUndefined)
  @IsString()
  @MaxLength(100)
  q?: string;
}

export class PatchOpsSupportTicketDto {
  @IsOptional()
  @IsIn(SUPPORT_TICKET_STATUSES)
  status?: SupportTicketStatus;

  @IsOptional()
  @IsIn(SUPPORT_TICKET_PRIORITIES)
  priority?: SupportTicketPriority;

  @Transform(trim)
  @IsString()
  @Length(3, 500)
  reason!: string;
}

export class SupportAttachmentParamsDto {
  @IsUUID()
  id!: string;

  @IsUUID()
  messageId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(SUPPORT_MAX_ATTACHMENTS - 1)
  index!: number;
}
