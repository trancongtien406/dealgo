import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export const DRIVER_HISTORY_KINDS = ['ALL', 'RIDE', 'FOOD_ORDER'] as const;
export type DriverHistoryKind = (typeof DRIVER_HISTORY_KINDS)[number];

export class DriverHistoryQueryDto {
  @IsOptional()
  @IsIn(DRIVER_HISTORY_KINDS)
  kind?: DriverHistoryKind;

  /** Opaque cursor from the previous page's nextCursor. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}
