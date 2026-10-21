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
import { OpsInterveneDto, RidePageQueryDto } from './ride.dto.js';
import { RideService } from './ride.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/rides')
@UseGuards(OpsPermissionGuard)
export class RideOpsController {
  constructor(
    private readonly rides: RideService,
    private readonly ledger: LedgerService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Ops paginated ride list' })
  list(@Query() query: RidePageQueryDto) {
    return this.rides.listForOps(query.page, query.limit, {
      status: query.status,
      q: query.q,
      zone: query.zone,
      serviceType: query.serviceType,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ops ride detail' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.rides.getForOps(id);
  }

  @Get(':id/ledger')
  @ApiOperation({ summary: 'Ops sandbox COD ledger journal for a ride' })
  getLedger(@Param('id', ParseUUIDPipe) id: string) {
    return this.ledger.getJournal('RIDE', id);
  }

  @RequireOpsPermission('rides.intervene')
  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Ops cancel ride (CAP-OPS-05). Allowed while NEGOTIATING / pre-trip / IN_TRIP. Writes OpsAuditLog + outbox.',
  })
  cancel(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OpsInterveneDto,
  ) {
    return this.rides.opsCancel(actor, id, dto.reason);
  }

  @RequireOpsPermission('rides.intervene')
  @Post(':id/reassign')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Clear ride assignment back to NEGOTIATING when status is ASSIGNED / DRIVER_EN_ROUTE / DRIVER_ARRIVED.',
  })
  reassign(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OpsInterveneDto,
  ) {
    return this.rides.opsReassign(actor, id, dto.reason);
  }
}

export { RideOpsController as OpsRidesController };
