import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { MerchantStatementQueryDto, RecordMerchantSettlementDto } from './food.dto.js';
import { FoodService } from './food.service.js';

/** (OPEN-018) Store commission statements and recorded settlements. */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/food-stores')
@UseGuards(OpsPermissionGuard)
export class MerchantSettlementOpsController {
  constructor(private readonly food: FoodService) {}

  @RequireOpsPermission('settlements.read')
  @Get(':id/statement')
  @ApiOperation({ summary: 'Store commission statement by Vietnam day (max 31 days)' })
  statement(@Param('id', ParseUUIDPipe) id: string, @Query() query: MerchantStatementQueryDto) {
    return this.food.opsMerchantStatement(id, query.from, query.to);
  }

  @RequireOpsPermission('settlements.write')
  @Post(':id/settlements')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Record that the store paid the commission for a closed ICT period (no overlaps; audited)',
  })
  record(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RecordMerchantSettlementDto,
  ) {
    return this.food.opsRecordMerchantSettlement(actor, id, dto);
  }
}
