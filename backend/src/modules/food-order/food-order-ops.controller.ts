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
import { LedgerService } from '../ledger/ledger.service.js';
import { OpsInterveneDto, OpsPageQueryDto } from './food.dto.js';
import { FoodService } from './food.service.js';
import { opsDateWindow } from '../operations/ops-date-window.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/food-orders')
@UseGuards(OpsPermissionGuard)
export class FoodOrderOpsController {
  constructor(
    private readonly food: FoodService,
    private readonly ledger: LedgerService,
  ) {}

  @Get()
  @ApiOperation({
    summary:
      'Ops paginated food order list; optional from/to (inclusive Vietnam business days on createdAt)',
  })
  list(@Query() query: OpsPageQueryDto) {
    const statuses = parseStatusesCsv(query.statuses);
    return this.food.listForOps(query.page, query.limit, {
      status: query.status,
      ...(statuses ? { statuses } : {}),
      q: query.q,
      store: query.store,
      payment: query.payment,
      zone: query.zone,
      window: opsDateWindow(query),
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ops food order detail' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.food.getForOps(id);
  }

  @Get(':id/ledger')
  @ApiOperation({ summary: 'Ops sandbox COD ledger journal for a food order' })
  getLedger(@Param('id', ParseUUIDPipe) id: string) {
    return this.ledger.getJournal('FOOD_ORDER', id);
  }

  @RequireOpsPermission('orders.intervene')
  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Ops cancel food order (CAP-OPS-05). Allowed until DELIVERED/FAILED/CANCELLED. Writes OpsAuditLog + outbox.',
  })
  cancel(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OpsInterveneDto,
  ) {
    return this.food.opsCancel(actor, id, dto.reason);
  }

  @RequireOpsPermission('orders.intervene')
  @Post(':id/reassign')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Clear food assignment back to READY when status is ASSIGNED.',
  })
  reassign(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OpsInterveneDto,
  ) {
    return this.food.opsReassign(actor, id, dto.reason);
  }
}

function parseStatusesCsv(raw: string | undefined): string[] | undefined {
  if (!raw?.trim()) {
    return undefined;
  }
  const statuses = raw
    .split(',')
    .map((s) => s.trim().toUpperCase())
    .filter(Boolean);
  return statuses.length > 0 ? statuses : undefined;
}

export { FoodOrderOpsController as OpsFoodOrdersController, FoodOrderOpsController as FoodOpsController };
