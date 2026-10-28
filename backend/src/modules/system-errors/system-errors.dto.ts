import {
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import {
  ISSUE_PERIODS,
  ISSUE_SORTS,
  ISSUE_STATUS_UPDATES,
  ISSUE_STATUSES,
} from './system-errors.service.js';

class ReasonDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

/** Omitted = unchanged; null or '' = clear. `projects` is a comma-separated slug list. */
export class PutSentrySettingsDto extends ReasonDto {
  @IsOptional() @IsString() @MaxLength(64) org?: string | null;
  @IsOptional() @IsString() @MaxLength(64) region?: string | null;
  @IsOptional() @IsString() @MaxLength(700) projects?: string | null;
  @IsOptional() @IsString() @MaxLength(512) authToken?: string | null;
}

export class TestSentryDto extends ReasonDto {}

export class IssueListQueryDto {
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_-]{0,63}$/)
  project?: string;
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[A-Za-z0-9._-]+$/)
  environment?: string;
  @IsOptional() @IsIn(ISSUE_STATUSES) status?: (typeof ISSUE_STATUSES)[number];
  @IsOptional() @IsIn(ISSUE_PERIODS) period?: (typeof ISSUE_PERIODS)[number];
  @IsOptional() @IsIn(ISSUE_SORTS) sort?: (typeof ISSUE_SORTS)[number];
  @IsOptional() @IsString() @MaxLength(200) q?: string;
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @Matches(/^[0-9:-]+$/)
  cursor?: string;
}

export class UpdateIssueStatusDto extends ReasonDto {
  @IsIn(ISSUE_STATUS_UPDATES) status!: (typeof ISSUE_STATUS_UPDATES)[number];
}
