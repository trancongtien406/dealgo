import { ConfigService } from '@nestjs/config';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MockMailSender } from '../../integrations/email/mail-sender.js';
import type { AppEnv } from '../../platform/config/env.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { MemoryPlatformSettingsRepository } from '../../platform/settings/platform-settings.repository.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { MemoryAuthMethodPolicyRepository } from './auth-method.repository.js';
import { EmailPasswordAuthService } from './email-password-auth.service.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { PasswordResetService } from './password-reset.service.js';
import { SessionService } from './session.service.js';

const ACTOR = '00000000-0000-4000-8000-000000000001';

describe('PasswordResetService (DEC-PROD-045 email code)', () => {
  let repository: MemoryIdentityRepository;
  let mail: MockMailSender;
  let sessions: SessionService;
  let auth: EmailPasswordAuthService;
  let settings: PlatformSettingsService;
  let resets: PasswordResetService;

  beforeEach(async () => {
    repository = new MemoryIdentityRepository();
    mail = new MockMailSender('test');
    const authMethods = new AuthMethodPolicyService(new MemoryAuthMethodPolicyRepository());
    const passwords = new PasswordHasher();
    await passwords.onModuleInit();
    const values: Partial<AppEnv> = {
      NODE_ENV: 'test',
      JWT_ACCESS_SECRET: 'test-secret-at-least-32-characters-long-key',
      JWT_ACCESS_TTL_SECONDS: 900,
      JWT_REFRESH_TTL_SECONDS: 604800,
    };
    const config = {
      get: (key: keyof AppEnv) => values[key],
    } as unknown as ConfigService<AppEnv, true>;
    sessions = new SessionService(repository, config);
    auth = new EmailPasswordAuthService(repository, sessions, passwords, authMethods, mail, config);
    settings = new PlatformSettingsService(new MemoryPlatformSettingsRepository(), config);
    resets = new PasswordResetService(repository, mail, passwords, config, authMethods, settings);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  async function registered(email: string, password = 'old-password') {
    const challenge = await auth.register({ email, password });
    return auth.verifyRegistration(challenge.challengeId, mail.signupCodes.at(-1)!.code);
  }

  it('answers an unknown email like a real one but sends nothing and never verifies', async () => {
    const view = await resets.request('nobody@dealgo.vn');
    expect(view).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    expect(mail.passwordResets).toHaveLength(0);
    await expect(resets.confirm(view.challengeId, '123456', 'new-password')).rejects.toMatchObject({
      status: 401,
    });
  });

  it('resets with the emailed code once, revokes sessions and keeps the old code dead', async () => {
    const session = await registered('reset@dealgo.vn');
    const view = await resets.request('Reset@DealGo.vn');
    const delivered = mail.passwordResets.at(-1)!;
    expect(delivered.email).toBe('reset@dealgo.vn');
    expect(delivered.code).toMatch(/^\d{6}$/);
    expect(new Date(view.expiresAt).getTime() - Date.now()).toBeLessThanOrEqual(10 * 60_000);

    const wrong = delivered.code === '000000' ? '111111' : '000000';
    await expect(resets.confirm(view.challengeId, wrong, 'new-password')).rejects.toMatchObject({
      status: 401,
    });
    await expect(resets.confirm(view.challengeId, delivered.code, 'new-password')).resolves.toEqual({
      reset: true,
    });
    await expect(
      resets.confirm(view.challengeId, delivered.code, 'another-password'),
    ).rejects.toMatchObject({ status: 401 });

    await expect(auth.login({ email: 'reset@dealgo.vn', password: 'old-password' })).rejects.toMatchObject({
      status: 401,
    });
    await expect(
      auth.login({ email: 'reset@dealgo.vn', password: 'new-password' }),
    ).resolves.toMatchObject({ user: { email: 'reset@dealgo.vn' } });
    await expect(sessions.refresh(session.refreshToken)).rejects.toMatchObject({ status: 401 });
  });

  it('locks after the admin-set number of wrong codes, even for the right code', async () => {
    await settings.patch('AUTH_PASSWORD_RESET_MAX_ATTEMPTS', '3', 'tighter', ACTOR);
    await registered('lock@dealgo.vn');
    const view = await resets.request('lock@dealgo.vn');
    const code = mail.passwordResets.at(-1)!.code;
    const wrong = code === '000000' ? '111111' : '000000';
    await expect(resets.confirm(view.challengeId, wrong, 'new-password')).rejects.toMatchObject({ status: 401 });
    await expect(resets.confirm(view.challengeId, wrong, 'new-password')).rejects.toMatchObject({ status: 401 });
    await expect(resets.confirm(view.challengeId, wrong, 'new-password')).rejects.toMatchObject({
      status: 429,
      response: { errorCode: 'AUTH_CODE_LOCKED' },
    });
    await expect(resets.confirm(view.challengeId, code, 'new-password')).rejects.toMatchObject({
      status: 429,
    });
    await expect(resets.resend(view.challengeId)).rejects.toMatchObject({ status: 429 });
  });

  it('caps challenges per email per hour from settings', async () => {
    await settings.patch('AUTH_PASSWORD_RESET_MAX_PER_HOUR', '2', 'tighter', ACTOR);
    await resets.request('cap@dealgo.vn');
    await resets.request('cap@dealgo.vn');
    await expect(resets.request('cap@dealgo.vn')).rejects.toMatchObject({
      status: 429,
      response: { errorCode: 'AUTH_OTP_RATE_LIMITED' },
    });
  });

  it('expires codes after the configured minutes and resends only after the cooldown', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-10-20T08:00:00Z'));
    await settings.patch('AUTH_PASSWORD_RESET_CODE_TTL_MINUTES', '5', 'shorter', ACTOR);
    await registered('ttl@dealgo.vn');
    const view = await resets.request('ttl@dealgo.vn');
    const first = mail.passwordResets.at(-1)!.code;
    expect(view.expiresAt).toBe('2026-10-20T08:05:00.000Z');

    await expect(resets.resend(view.challengeId)).rejects.toMatchObject({
      response: { errorCode: 'AUTH_OTP_RESEND_COOLDOWN' },
    });
    vi.setSystemTime(new Date('2026-10-20T08:06:00Z'));
    await expect(resets.confirm(view.challengeId, first, 'new-password')).rejects.toMatchObject({
      response: { errorCode: 'AUTH_CODE_EXPIRED' },
    });
    const again = await resets.resend(view.challengeId);
    expect(again.expiresAt).toBe('2026-10-20T08:11:00.000Z');
    const second = mail.passwordResets.at(-1)!.code;
    await expect(resets.confirm(view.challengeId, second, 'new-password')).resolves.toEqual({
      reset: true,
    });
  });

  it('lets an account created before OTP sign-up verify its email by resetting the password', async () => {
    const legacy = await repository.createUser({
      email: 'legacy@dealgo.vn',
      phone: null,
      displayName: 'Legacy',
    });
    await repository.saveCustomerCredential(legacy.id, 'not-a-real-hash');
    const view = await resets.request('legacy@dealgo.vn');
    await resets.confirm(view.challengeId, mail.passwordResets.at(-1)!.code, 'fresh-password');

    expect((await repository.findUserById(legacy.id))?.emailVerifiedAt).toBeInstanceOf(Date);
    await expect(
      auth.login({ email: 'legacy@dealgo.vn', password: 'fresh-password' }),
    ).resolves.toMatchObject({ user: { id: legacy.id } });
  });
});
