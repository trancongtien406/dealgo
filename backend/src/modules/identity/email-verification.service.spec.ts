import { afterEach, describe, expect, it, vi } from 'vitest';
import { MockMailSender } from '../../integrations/email/mail-sender.js';
import { EmailVerificationService } from './email-verification.service.js';
import { MemoryIdentityRepository } from './identity.repository.js';

async function setup() {
  const repository = new MemoryIdentityRepository();
  const mail = new MockMailSender('test');
  const config = { get: vi.fn((key: string) => (key === 'NODE_ENV' ? 'test' : undefined)) };
  const authMethods = { assertEnabled: vi.fn().mockResolvedValue(undefined) };
  const service = new EmailVerificationService(repository, mail, config as any, authMethods as any);
  const user = await repository.createUser({ phone: null, email: 'lan@x.vn', displayName: 'Lan' });
  return { repository, mail, service, user };
}

function errorCode(error: unknown): string | undefined {
  return (error as { response?: { errorCode?: string } }).response?.errorCode;
}

describe('EmailVerificationService', () => {
  afterEach(() => vi.useRealTimers());

  it('mails a 6-digit code and verifies the address on confirm', async () => {
    const { repository, mail, service, user } = await setup();

    const view = await service.request(user.id, 'Lan@X.vn');
    expect(mail.sent).toHaveLength(1);
    expect(mail.sent[0]).toMatchObject({ email: 'lan@x.vn', code: expect.stringMatching(/^\d{6}$/) });
    expect(view).toEqual({
      verificationId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });

    await expect(service.confirm(view.verificationId, mail.sent[0]!.code)).resolves.toEqual({ verified: true });
    expect((await repository.findUserById(user.id))?.emailVerifiedAt).toBeInstanceOf(Date);
    await expect(service.confirm(view.verificationId, mail.sent[0]!.code)).rejects.toSatisfy(
      (error) => errorCode(error) === 'AUTH_CODE_INVALID',
    );
  });

  it('reuses the live code inside the resend cooldown instead of mailing again', async () => {
    vi.useFakeTimers({ now: new Date('2026-11-02T12:00:00.000Z') });
    const { mail, service, user } = await setup();

    const first = await service.request(user.id, 'lan@x.vn');
    const again = await service.request(user.id, 'lan@x.vn');
    expect(again.verificationId).toBe(first.verificationId);
    expect(mail.sent).toHaveLength(1);

    vi.setSystemTime(new Date('2026-11-02T12:01:01.000Z'));
    const resent = await service.request(user.id, 'lan@x.vn');
    expect(resent.verificationId).not.toBe(first.verificationId);
    expect(mail.sent).toHaveLength(2);
  });

  it('caps codes per user per hour', async () => {
    vi.useFakeTimers({ now: new Date('2026-11-02T12:00:00.000Z') });
    const { service, user } = await setup();
    for (let i = 0; i < 5; i += 1) {
      vi.setSystemTime(new Date(Date.parse('2026-11-02T12:00:00.000Z') + i * 61_000));
      await service.request(user.id, 'lan@x.vn');
    }
    vi.setSystemTime(new Date(Date.parse('2026-11-02T12:00:00.000Z') + 5 * 61_000));
    await expect(service.request(user.id, 'lan@x.vn')).rejects.toSatisfy(
      (error) => errorCode(error) === 'AUTH_OTP_RATE_LIMITED',
    );
  });

  it('locks the code after 5 wrong guesses, even for the right code afterwards', async () => {
    const { mail, service, user } = await setup();
    const view = await service.request(user.id, 'lan@x.vn');
    const right = mail.sent[0]!.code;
    const wrong = right === '000000' ? '111111' : '000000';

    for (let i = 0; i < 4; i += 1) {
      await expect(service.confirm(view.verificationId, wrong)).rejects.toSatisfy(
        (error) => errorCode(error) === 'AUTH_CODE_INVALID',
      );
    }
    await expect(service.confirm(view.verificationId, wrong)).rejects.toSatisfy(
      (error) => errorCode(error) === 'AUTH_CODE_LOCKED',
    );
    await expect(service.confirm(view.verificationId, right)).rejects.toSatisfy(
      (error) => errorCode(error) === 'AUTH_CODE_LOCKED',
    );
  });

  it('rejects an expired code', async () => {
    vi.useFakeTimers({ now: new Date('2026-11-02T12:00:00.000Z') });
    const { mail, service, user } = await setup();
    const view = await service.request(user.id, 'lan@x.vn');
    vi.setSystemTime(new Date('2026-11-02T12:10:01.000Z'));
    await expect(service.confirm(view.verificationId, mail.sent[0]!.code)).rejects.toSatisfy(
      (error) => errorCode(error) === 'AUTH_CODE_EXPIRED',
    );
  });

  it('refuses an address that is already verified on this account', async () => {
    const { repository, mail, service, user } = await setup();
    await repository.setEmailVerified(user.id, 'lan@x.vn', new Date());
    await expect(service.request(user.id, 'lan@x.vn')).rejects.toSatisfy(
      (error) => errorCode(error) === 'EMAIL_ALREADY_VERIFIED',
    );
    expect(mail.sent).toHaveLength(0);
  });
});
