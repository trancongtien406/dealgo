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

  @ApiPropertyOptional({ description: 'Caller latitude for proximity bias', example: 10.7745 })
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  lat?: number;

  @ApiPropertyOptional({ description: 'Caller longitude for proximity bias', example: 106.703 })
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  lng?: number;
}

export class RecordPlaceHistoryDto {
  @ApiProperty({ maxLength: 160, example: '12 Nguyễn Hoàng' })
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  name!: string;

  @ApiPropertyOptional({ maxLength: 300, example: '12 Nguyễn Hoàng, Hòa Cường, Đà Nẵng' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  address?: string;

  @ApiProperty({ example: 16.0603 })
  @Type(() => Number)
  @IsLatitude()
  lat!: number;

  @ApiProperty({ example: 108.2101 })
  @Type(() => Number)
  @IsLongitude()
  lng!: number;
}
