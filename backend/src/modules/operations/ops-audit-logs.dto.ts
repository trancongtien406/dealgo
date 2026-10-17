import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ListOpsAuditLogsQueryDto {
  @ApiPropertyOptional({ description: 'Filter by action name or search query' })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({ description: 'Filter by entity type (RIDE, FOOD_ORDER, SETTINGS, DISPUTE, FAQ)' })
  @IsOptional()
  @IsString()
  entityType?: string;

  @ApiPropertyOptional({ description: 'Filter by result tone / status (SUCCESS, PENDING_APPROVAL, LOGGED, REJECTED)' })
  @IsOptional()
  @IsString()
  result?: string;

  @ApiPropertyOptional({ description: 'Page number (1-based)', default: 1 })
  @IsOptional()
  page?: number;

  @ApiPropertyOptional({ description: 'Page limit (1-100)', default: 20 })
  @IsOptional()
  limit?: number;
}
