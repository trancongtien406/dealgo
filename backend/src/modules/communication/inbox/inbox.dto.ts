import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export const INBOX_CATEGORIES = ['RIDE', 'FOOD', 'PROMOTION', 'SYSTEM'] as const;

export class ListInboxQueryDto {
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
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  unreadOnly?: boolean;

  @IsOptional()
  @IsIn(INBOX_CATEGORIES)
  category?: (typeof INBOX_CATEGORIES)[number];
}
