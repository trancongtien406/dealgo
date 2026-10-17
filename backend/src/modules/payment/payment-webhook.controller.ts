import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Inject,
  Post,
  Query,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { AppEnv } from '../../platform/config/env.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { PAYMENT_REPOSITORY } from './payment.constants.js';
import type { PaymentRepository } from './payment.repository.js';
import { verifyMomoSignature } from '../../integrations/payment-gateways/momo-payment.port.js';
import { verifyVnpaySecureHash } from '../../integrations/payment-gateways/vnpay-payment.port.js';

/**
 * PSP IPN stubs. When hash secrets are set, verify signature then mark intent
 * SANDBOX_RECORDED or CAPTURED_STUB. Idempotent by provider event id.
 * Does not claim real settlement / ledger capture.
 */
@ApiTags('payments')
@Controller('v1/payments/webhooks')
export class PaymentWebhookController {
  constructor(
    @Inject(PAYMENT_REPOSITORY) private readonly payments: PaymentRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  @Post('vnpay')
  @HttpCode(HttpStatus.OK)
  @SkipResponseEnvelope()
  @ApiOperation({
    summary: 'VNPAY IPN stub — verify SecureHash when VNPAY_HASH_SECRET set; idempotent event id',
  })
  async vnpay(
    @Query() query: Record<string, string>,
    @Body() body: Record<string, string>,
  ) {
    const params = { ...query, ...body };
    const hashSecret = this.config.get('VNPAY_HASH_SECRET', { infer: true });
    if (!hashSecret) {
      throw new BadRequestException({ RspCode: '99', Message: 'Missing hash secret configuration' });
    }
    if (!verifyVnpaySecureHash(params, hashSecret)) {
      throw new BadRequestException({ RspCode: '97', Message: 'Invalid signature' });
    }
    const providerRef = params.vnp_TxnRef;
    const providerEventId =
      params.vnp_TransactionNo ||
      params.vnp_TxnRef ||
      `vnpay-${params.vnp_PayDate ?? 'unknown'}`;
    if (!providerEventId) {
      throw new BadRequestException({ RspCode: '01', Message: 'Missing event id' });
    }
    const resultCode = params.vnp_ResponseCode;
    const markStatus = resultCode === '00' ? 'CAPTURED_STUB' : 'SANDBOX_RECORDED';
    const result = await this.payments.recordWebhook({
      provider: 'vnpay',
      providerEventId: String(providerEventId),
      providerRef: providerRef ? String(providerRef) : undefined,
      markStatus,
    });
    return {
      RspCode: '00',
      Message: result.duplicate ? 'Already confirmed' : 'Confirm Success',
      duplicate: result.duplicate,
      status: markStatus,
    };
  }

  @Post('momo')
  @HttpCode(HttpStatus.OK)
  @SkipResponseEnvelope()
  @ApiOperation({
    summary: 'MoMo IPN stub — verify signature when MoMo keys set; idempotent by orderId/transId',
  })
  async momo(
    @Body() body: Record<string, unknown>,
    @Headers('x-momo-signature') _headerSig: string | undefined,
  ) {
    const accessKey = this.config.get('MOMO_ACCESS_KEY', { infer: true });
    const secretKey = this.config.get('MOMO_SECRET_KEY', { infer: true });
    if (!accessKey || !secretKey) {
      return { resultCode: 99, message: 'Missing MoMo webhook credentials configuration' };
    }
    if (!verifyMomoSignature(body, { accessKey, secretKey })) {
      return { resultCode: 97, message: 'Invalid signature' };
    }
    const providerRef = typeof body.orderId === 'string' ? body.orderId : undefined;
    const providerEventId =
      (typeof body.transId === 'string' || typeof body.transId === 'number'
        ? String(body.transId)
        : undefined) ||
      providerRef ||
      'momo-unknown';
    const resultCode = Number(body.resultCode);
    const markStatus = resultCode === 0 ? 'CAPTURED_STUB' : 'SANDBOX_RECORDED';
    const result = await this.payments.recordWebhook({
      provider: 'momo',
      providerEventId,
      providerRef,
      markStatus,
    });
    return {
      resultCode: 0,
      message: result.duplicate ? 'Already processed' : 'Success',
      duplicate: result.duplicate,
      status: markStatus,
    };
  }
}
