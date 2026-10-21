import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class ReversePlaceQueryDto {
  @ApiProperty({ minimum: -90, maximum: 90, example: 16.068 })
  @Type(() => Number)
  @IsLatitude()
  lat!: number;

  @ApiProperty({ minimum: -180, maximum: 180, example: 108.2235 })
  @Type(() => Number)
  @IsLongitude()
  lng!: number;
}

export class SearchPlacesQueryDto {
  @ApiProperty({ minLength: 2, maxLength: 120, example: 'chợ hàn' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  q!: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 10, default: 8 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  limit?: number;
}
