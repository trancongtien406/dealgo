import { HttpException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { APP_REVIEW_MAX_CODES_PER_HOUR, AppReviewLoginService } from './app-review-login.service.js';

function build(opts: { enabled?: boolean; code?: string; phone?: string; email?: string } = {}) {
  const env: Record<string, unknown> = { APP_REVIEW_OTP_CODE: 'code' in opts ? opts.code : '246810' };
  const config = { get: (key: string) => env[key] } as never;
  const settings = {
    getBoolean: vi.fn(async () => opts.enabled ?? true),
    getString: vi.fn(async (key: string) =>
      key === 'APP_REVIEW_PHONE' ? (opts.phone ?? '0901234567') : (opts.email ?? 'Review@DealGo.vn'),
    ),
  } as never;
  const create = vi.fn(async () => ({}));
  const prisma = { db: () => ({ opsAuditLog: { create } }) } as never;
  return { service: new AppReviewLoginService(config, settings, prisma), create };
}

describe('AppReviewLoginService', () => {
  it('returns the fixed code only for the configured phone and email', async () => {
    const { service } = build();
    await expect(service.fixedCodeFor('phone', '+84901234567')).resolves.toBe('246810');
    await expect(service.fixedCodeFor('email', 'review@dealgo.vn')).resolves.toBe('246810');
    await expect(service.fixedCodeFor('phone', '+84909999999')).resolves.toBeNull();
    await expect(service.fixedCodeFor('email', 'someone@dealgo.vn')).resolves.toBeNull();
  });

  it('is inert when disabled, unconfigured, or without an env code', async () => {
    await expect(build({ enabled: false }).service.fixedCodeFor('phone', '0901234567')).resolves.toBeNull();
    await expect(build({ code: undefined }).service.fixedCodeFor('phone', '0901234567')).resolves.toBeNull();
    await expect(build({ email: '' }).service.fixedCodeFor('email', '')).resolves.toBeNull();
    await expect(build({ phone: '' }).service.fixedCodeFor('phone', '0901234567')).resolves.toBeNull();
  });

  it('rate-limits code issuance', async () => {
    const { service } = build();
    for (let i = 0; i < APP_REVIEW_MAX_CODES_PER_HOUR; i += 1) {
      await service.fixedCodeFor('phone', '0901234567');
    }
    const error = await service.fixedCodeFor('phone', '0901234567').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpException);
    expect((error as HttpException).getStatus()).toBe(429);
  });

  it('audits review sign-ins', async () => {
    const { service, create } = build();
    await service.recordSignIn('user-1', 'email');
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({ action: 'APP_REVIEW_LOGIN', entityType: 'USER', entityId: 'user-1' }),
    });
  });
});
