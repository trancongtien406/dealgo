import { EarningsService } from '../earnings/earnings.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  ConfirmAccountDeletionDto,
  OpsDriverPaymentDto,
  OpsReasonDto,
} from './account-deletion.dto.js';
import { AccountDeletionService } from './account-deletion.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/me/account-deletion')
@UseGuards(CustomerSessionGuard)
export class AccountDeletionController {
  constructor(private readonly deletion: AccountDeletionService) {}

  @Get()
  @ApiOperation({ summary: 'S027: grace days, re-auth method, blockers and latest request status' })
  overview(@CurrentActor() actor: RequestActor) {
    return this.deletion.overview(actor.userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'S027: start deletion; 409 ACCOUNT_DELETION_BLOCKED lists blockers; sends SMS OTP',
  })
  start(@CurrentActor() actor: RequestActor) {
    return this.deletion.start(actor.userId);
  }

  @Post(':id/confirm')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'S027: re-auth (code or password) → soft-delete, revoke all sessions, schedule purge',
  })
  confirm(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: ConfirmAccountDeletionDto,
  ) {
    return this.deletion.confirm(actor.userId, id, { code: body.code, password: body.password });
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/users')
@UseGuards(OpsPermissionGuard)
export class OpsAccountDeletionController {
  constructor(
    private readonly deletion: AccountDeletionService,
    private readonly earnings: EarningsService,
    private readonly settings: PlatformSettingsService,
  ) {}

  @RequireOpsPermission('customers.write')
  @Post(':id/account-deletion/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Restore an account during its deletion grace period (audited)' })
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsReasonDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.deletion.cancelByOps({ actorUserId: actor.userId, userId: id, reason: body.reason });
  }

  @Get(':id/fee-balance')
  @ApiOperation({ summary: 'Driver platform fee accrued on cash jobs and not yet settled' })
  feeBalance(@Param('id', ParseUUIDPipe) id: string) {
    return this.deletion.driverFeeBalance(id);
  }

  @RequireOpsPermission('settlements.read')
  @Get(':id/driver-balance')
  @ApiOperation({
    summary:
      'Unsettled fees + signed adjustments (cancel/no-show fee hand-overs, voucher reimbursements) vs DRIVER_DEBT_LIMIT_VND',
  })
  async driverBalance(@Param('id', ParseUUIDPipe) id: string) {
    await this.deletion.driverFeeBalance(id); // 404 for unknown users
    const [balance, adjustments, limitVnd, cancelRate] = await Promise.all([
      this.earnings.balanceOf(id),
      this.earnings.listAdjustments(id, 50),
      this.settings.getNumber('DRIVER_DEBT_LIMIT_VND'),
      this.earnings.cancelRate(id),
    ]);
    return {
      feesVnd: balance.feesVnd,
      adjustmentsVnd: balance.adjustmentsVnd,
      amountVnd: balance.amountVnd,
      settledThrough: balance.settledThrough?.toISOString() ?? null,
      limitVnd,
      blocked: limitVnd > 0 && balance.amountVnd > limitVnd,
      cancelRate,
      adjustments: adjustments.map((row) => ({
        id: row.id,
        kind: row.kind,
        amountVnd: row.amountVnd,
        refType: row.refType,
        refId: row.refId,
        occurredAt: row.occurredAt.toISOString(),
      })),
    };
  }

  @RequireOpsPermission('settlements.write')
  @Post(':id/driver-payments')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Record a partial driver payment / top-up or a DealGo payout (audited)',
  })
  driverPayment(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsDriverPaymentDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.deletion.recordDriverPayment({
      actorUserId: actor.userId,
      driverId: id,
      direction: body.direction,
      amountVnd: body.amountVnd,
      reason: body.reason,
    });
  }

  @RequireOpsPermission('settlements.write')
  @Post(':id/fee-settlements')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Ops confirms the driver paid the outstanding platform fee (audited)' })
  settle(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsReasonDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.deletion.settleDriverFees({ actorUserId: actor.userId, driverId: id, reason: body.reason });
  }
}
