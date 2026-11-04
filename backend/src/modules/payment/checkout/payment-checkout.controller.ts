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
  Res,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { SkipResponseEnvelope } from '../../../platform/http/skip-response-envelope.js';
import { CustomerSessionGuard } from '../../identity/access-auth.guard.js';
import { DriverCreditService } from '../../driver-credit/driver-credit.service.js';
import type { PaymentEntityTypeName, PaymentProviderName } from '../payment.constants.js';
import { PaymentMethodsQueryDto } from './payment-checkout.dto.js';
import { PaymentGatewayService } from './payment-gateway.service.js';
import { PaymentMethodRegistryService } from './payment-method-registry.service.js';

const IPN_PROVIDERS: readonly PaymentProviderName[] = ['momo', 'zalopay', 'vnpay', 'payos'];

@ApiTags('payments')
@ApiBearerAuth()
@Controller('v1/payments')
@UseGuards(CustomerSessionGuard)
export class PaymentMethodsController {
  constructor(private readonly registry: PaymentMethodRegistryService) {}

  @Get('methods')
  @ApiOperation({ summary: 'Payment methods for a service (BIKE/CAR/FOOD) with availability + reason' })
  async methods(@Query() query: PaymentMethodsQueryDto) {
    return { service: query.service, methods: await this.registry.list(query.service) };
  }
}

/** PSP server-to-server callbacks + browser return. Public (signature-verified). */
@ApiTags('payments')
@Controller('v1/payments')
export class PaymentCallbacksController {
  constructor(
    private readonly gateway: PaymentGatewayService,
    private readonly driverCredit: DriverCreditService,
  ) {}

  @Post('ipn/:provider')
  @HttpCode(HttpStatus.OK)
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Signed IPN/callback (MoMo, ZaloPay, VNPay POST). Idempotent.' })
  async ipnPost(
    @Param('provider') provider: string,
    @Query() query: Record<string, unknown>,
    @Body() body: Record<string, unknown>,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.ipn(provider, { ...(query ?? {}), ...(body ?? {}) }, res);
  }

  @Get('ipn/:provider')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'VNPay IPN (GET with vnp_* query). Idempotent.' })
  async ipnGet(
    @Param('provider') provider: string,
    @Query() query: Record<string, unknown>,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.ipn(provider, query ?? {}, res);
  }

  @Get('return/:provider/:entityType/:entityId')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Browser return from the PSP page; bounces to the app deeplink with status' })
  async back(
    @Param('entityType') entityTypeRaw: string,
    @Param('entityId', new ParseUUIDPipe()) entityId: string,
    @Res() res: Response,
  ) {
    const entityType: PaymentEntityTypeName = entityTypeRaw === 'RIDE' ? 'RIDE' : 'FOOD_ORDER';
    const { url, view } = await this.gateway.returnRedirect(entityType, entityId);
    if (url) {
      res.redirect(302, url);
      return;
    }
    res
      .status(200)
      .type('html')
      .send(
        `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">` +
          `<p style="font-family:sans-serif;text-align:center;margin-top:40px">` +
          `Trạng thái thanh toán: <b>${view.status}</b>. Bạn có thể quay lại ứng dụng DealGo.</p>`,
      );
  }

  private async ipn(provider: string, payload: Record<string, unknown>, res: Response) {
    if (!(IPN_PROVIDERS as readonly string[]).includes(provider)) {
      res.status(404);
      return { message: 'Unknown provider' };
    }
    if (this.driverCredit.isDriverTopUpCallback(provider, payload)) {
      const ack = await this.driverCredit.handleProviderCallback(provider, payload);
      res.status(ack.httpStatus);
      return ack.body;
    }
    const ack = await this.gateway.handleCallback(provider as PaymentProviderName, payload);
    res.status(ack.httpStatus);
    return ack.body;
  }
}
