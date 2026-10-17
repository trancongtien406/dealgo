import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export const DISPUTE_REMEDIES = [
  'evidence',
  'partial',
  'full',
  'reject',
] as const;

export type DisputeRemedy = (typeof DISPUTE_REMEDIES)[number];

export class ResolveDisputeDto {
  @ApiProperty({
    enum: DISPUTE_REMEDIES,
    description: 'Remedy action chosen by operator',
    example: 'partial',
  })
  @IsEnum(DISPUTE_REMEDIES)
  remedy: DisputeRemedy;

  @ApiProperty({
    description: 'Reason and justification for the decision (recorded in audit log)',
    example: 'Khách cung cấp ảnh thiếu 1 phần topping; đối soát xác nhận với quán hoàn một phần 35.000 VNĐ.',
    maxLength: 500,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;

  @ApiPropertyOptional({
    description: 'Internal operational note or feedback to parties',
    example: 'Đã thông báo quán Highlands để lưu ý đóng gói các đơn sau.',
    maxLength: 1000,
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  @ApiPropertyOptional({
    description: 'Refund amount in VND when partial refund is selected',
    example: 35000,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  amount?: number;
}
