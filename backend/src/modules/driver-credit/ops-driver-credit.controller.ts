import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { OpsDriverCreditRefundDto, OpsDriverTopUpQueryDto } from './driver-credit.dto.js';
import { DriverCreditService } from './driver-credit.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/driver-credit')
@UseGuards(OpsPermissionGuard)
export class OpsDriverCreditController {
  constructor(private readonly credit: DriverCreditService) {}

  @Get('top-ups')
  @RequireOpsPermission('drivers.read')
  @ApiOperation({ summary: 'Driver top-ups across all drivers, newest first' })
  list(@Query() query: OpsDriverTopUpQueryDto) {
    return this.credit.opsList({
      driverId: query.driverId,
      status: query.status,
      limit: query.limit ?? 50,
    });
  }

  @Get('top-ups/:id')
  @RequireOpsPermission('drivers.read')
  @ApiOperation({ summary: 'One driver top-up with provider, refund and consumption detail' })
  detail(@Param('id', new ParseUUIDPipe({ version: '4' })) id: string) {
    return this.credit.opsDetail(id);
  }

  @Get('summary')
  @RequireOpsPermission('settlements.read')
  @ApiOperation({ summary: 'Pending / today / refunded / outstanding driver credit totals' })
  summary() {
    return this.credit.opsSummary();
  }

  @Post('top-ups/:id/reconcile')
  @RequireOpsPermission('settlements.write')
  @ApiOperation({ summary: 'Ask the PSP for the truth on one pending top-up (missed callback)' })
  reconcile(@Param('id', new ParseUUIDPipe({ version: '4' })) id: string) {
    return this.credit.reconcileOne(id);
  }

  @Post('reconcile')
  @RequireOpsPermission('settlements.write')
  @ApiOperation({ summary: 'Sweep pending top-ups against the PSP (bounded batch)' })
  reconcileAll() {
    return this.credit.reconcilePending();
  }

  @Post('top-ups/:id/refund')
  @RequireOpsPermission('refunds.write')
  @ApiOperation({
    summary:
      'Record the manual bank transfer that returns unused credit (contract termination/closure)',
  })
  refund(
    @CurrentActor() actor: RequestActor,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() body: OpsDriverCreditRefundDto,
  ) {
    return this.credit.refundTopUp({
      actorUserId: actor.userId,
      topUpId: id,
      reason: body.reason,
      bankRef: body.bankRef,
    });
  }
}
