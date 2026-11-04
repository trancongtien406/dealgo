import { Controller, Get, Inject, Param, Query, Res } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import type { AppEnv } from '../../platform/config/env.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { DRIVER_CREDIT_REPOSITORY, type DriverCreditRepository } from './driver-credit.repository.js';

const STATUS_LABEL: Record<string, string> = {
  PENDING: 'Đang chờ thanh toán',
  PAID: 'Thanh toán thành công, tiền đã vào số dư tạm ứng',
  EXPIRED: 'Đã hết hạn',
  CANCELLED: 'Đã huỷ',
  FAILED: 'Thanh toán thất bại',
  REFUND_PENDING: 'Đang xử lý hoàn tiền',
  REFUNDED: 'Đã hoàn tiền',
};

/**
 * Browser landing page after the PSP redirect. Display only: the driver is credited solely by the
 * signature-verified IPN, so a forged `orderCode` can never move money.
 */
@ApiTags('payments')
@Controller('v1/payments/driver-credit')
export class DriverCreditReturnController {
  constructor(
    @Inject(DRIVER_CREDIT_REPOSITORY) private readonly repo: DriverCreditRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  @Get('return/:provider')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Browser return from the PSP for a driver top-up (display only)' })
  async back(
    @Param('provider') _provider: string,
    @Query('orderCode') orderCode: string | undefined,
    @Res() res: Response,
  ) {
    const code = Number.parseInt(String(orderCode ?? ''), 10);
    const row = Number.isSafeInteger(code) ? await this.repo.findByOrderCode(code) : null;
    const label = row ? (STATUS_LABEL[row.status] ?? row.status) : 'Không tìm thấy giao dịch';
    const appUrl = this.appReturnUrl(row?.status, row?.id);
    res
      .status(row ? 200 : 404)
      .type('html')
      .send(renderPage(label, appUrl));
  }

  private appReturnUrl(status?: string, topUpId?: string): string | null {
    const base = this.config.get('PAYMENT_APP_RETURN_URL', { infer: true });
    if (!base) {
      return null;
    }
    const params = new URLSearchParams({ kind: 'driver-credit' });
    if (status) {
      params.set('status', status);
    }
    if (topUpId) {
      params.set('topUpId', topUpId);
    }
    return `${base}${base.includes('?') ? '&' : '?'}${params.toString()}`;
  }
}

function renderPage(label: string, appUrl: string | null): string {
  const link = appUrl
    ? `<p><a href="${escapeHtml(appUrl)}" style="color:#0a7cff">Quay lại ứng dụng DealGo</a></p>`
    : '<p>Bạn có thể quay lại ứng dụng DealGo.</p>';
  return (
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">` +
    `<div style="font-family:sans-serif;text-align:center;margin-top:40px">` +
    `<p>Nạp tiền tài xế</p><p><b>${escapeHtml(label)}</b></p>${link}</div>`
  );
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
