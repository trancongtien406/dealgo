import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../../identity/access-auth.guard.js';
import { OpsPermissionGuard } from '../../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../../identity/ops-rbac/ops-permission.decorator.js';
import { OpsIntentsQueryDto, PatchPaymentMethodsDto, RefundIntentDto } from './payment-checkout.dto.js';
import { PaymentGatewayService } from './payment-gateway.service.js';
import { PaymentMethodRegistryService } from './payment-method-registry.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops')
@UseGuards(OpsPermissionGuard)
export class OpsPaymentsController {
  constructor(
    private readonly registry: PaymentMethodRegistryService,
    private readonly gateway: PaymentGatewayService,
  ) {}

  @Get('payment-methods')
  @ApiOperation({ summary: 'Payment method registry + provider config status (env key names only, no secrets)' })
  list() {
    return this.registry.listForOps();
  }

  @Patch('payment-methods')
  @RequireOpsPermission('settings.write')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Toggle methods per service, order, reason, wallet flag (audited via platform settings)' })
  patch(@CurrentActor() actor: RequestActor, @Body() body: PatchPaymentMethodsDto) {
    return this.registry.update(
      { methods: body.methods, walletEnabled: body.walletEnabled },
      body.reason,
      actor.userId,
    );
  }

  @Get('payment-intents')
  @RequireOpsPermission('refunds.read')
  @ApiOperation({ summary: 'Recent online payment intents' })
  intents(@Query() query: OpsIntentsQueryDto) {
    return this.gateway.listIntents(query.limit ?? 50, query.status, {
      provider: query.provider,
      entityType: query.entityType,
      q: query.q,
    });
  }

  @Get('payment-intents/:id')
  @RequireOpsPermission('refunds.read')
  @ApiOperation({ summary: 'Payment intent detail with refund history and refundable amount' })
  detail(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.gateway.intentDetail(id);
  }

  @Post('payment-intents/reconcile')
  @RequireOpsPermission('refunds.write')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Run provider status reconciliation now for pending attempts (idempotent)' })
  reconcile() {
    return this.gateway.reconcilePending(new Date(), { olderThanMs: 0 });
  }

  @Post('payment-intents/:id/refund')
  @RequireOpsPermission('refunds.write')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refund (partial or full, repeatable up to the captured amount) through the PSP; one journal per refund' })
  refund(
    @CurrentActor() actor: RequestActor,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: RefundIntentDto,
  ) {
    return this.gateway.refund({
      intentId: id,
      amountVnd: body.amountVnd,
      reason: body.reason,
      actorUserId: actor.userId,
      idempotencyKey: body.idempotencyKey,
    });
  }
}
