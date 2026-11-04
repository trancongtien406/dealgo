import { HttpException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AppEnv } from '../../platform/config/env.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { MailDeliveryError, MockMailSender, UnavailableMailSender } from '../../integrations/email/mail-sender.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { MemoryAuthMethodPolicyRepository } from './auth-method.repository.js';
import { EmailPasswordAuthService } from './email-password-auth.service.js';
import {
  EMAIL_SIGNUP_MAX_ATTEMPTS,
  EMAIL_SIGNUP_MAX_PER_HOUR,
  EMAIL_SIGNUP_MAX_SENDS,
  EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
  EMAIL_SIGNUP_TTL_MS,
} from './identity.constants.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { SessionService } from './session.service.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

async function errorOf(promise: Promise<unknown>): Promise<HttpException> {
  const error = await promise.catch((err: unknown) => err);
  expect(error).toBeInstanceOf(HttpException);
  return error as HttpException;
}

function expectError(error: HttpException, status: number, errorCode: string) {
  expect(error.getStatus()).toBe(status);
  expect(error.getResponse()).toMatchObject({ errorCode });
}

describe('EmailPasswordAuthService', () => {
  let repository: MemoryIdentityRepository;
  let authMethods: AuthMethodPolicyService;
  let passwords: PasswordHasher;
  let service: EmailPasswordAuthService;
  let mail: MockMailSender;
  let config: ConfigService<AppEnv, true>;
  let sessions: SessionService;

  beforeEach(async () => {
    repository = new MemoryIdentityRepository();
    authMethods = new AuthMethodPolicyService(new MemoryAuthMethodPolicyRepository());
    passwords = new PasswordHasher();
    await passwords.onModuleInit();

    const configValues: Partial<AppEnv> = {
      NODE_ENV: 'test',
      JWT_ACCESS_SECRET: 'test-secret-at-least-32-characters-long-key',
      JWT_ACCESS_TTL_SECONDS: 900,
      JWT_REFRESH_TTL_SECONDS: 604800,
    };
    config = {
      get: (key: keyof AppEnv) => configValues[key],
    } as unknown as ConfigService<AppEnv, true>;

    sessions = new SessionService(repository, config);
    mail = new MockMailSender('test');
    service = new EmailPasswordAuthService(repository, sessions, passwords, authMethods, mail, config);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  async function signUp(email: string, password = 'password123', displayName?: string) {
    const challenge = await service.register({ email, password, displayName });
    const code = mail.signupCodes.at(-1)!.code;
    return service.verifyRegistration(challenge.challengeId, code);
  }

  it('creates no account until the emailed code is verified', async () => {
    const challenge = await service.register({
      email: '  Ana@DealGo.vn ',
      password: 'password123',
      displayName: 'Ana Nguyen',
    });

    expect(challenge).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    expect(await repository.findUserByEmail('ana@dealgo.vn')).toBeNull();
    const delivered = mail.signupCodes.at(-1)!;
    expect(delivered.email).toBe('ana@dealgo.vn');
    expect(delivered.code).toMatch(/^\d{6}$/);
    expect(JSON.stringify(challenge)).not.toContain(delivered.code);
    const stored = await repository.findEmailSignupChallenge(challenge.challengeId);
    expect(stored?.codeHash).not.toContain(delivered.code);
    expect(stored?.passwordHash).not.toBe('password123');

    const session = await service.verifyRegistration(challenge.challengeId, delivered.code);

    expect(session.accessToken).toBeTruthy();
    expect(session.user.email).toBe('ana@dealgo.vn');
    const user = await repository.findUserById(session.user.id);
    expect(user?.displayName).toBe('Ana Nguyen');
    expect(user?.emailVerifiedAt).toBeInstanceOf(Date);
    expect(await repository.listGrants(session.user.id)).toEqual([
      expect.objectContaining({ role: 'CUSTOMER', status: 'ACTIVE' }),
    ]);
    expect((await repository.findCustomerCredential(session.user.id))?.passwordHash).toBeTruthy();

    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, delivered.code)),
      401,
      'AUTH_CODE_INVALID',
    );
  });

  it('rejects login before the code is verified', async () => {
    await service.register({ email: 'pending@dealgo.vn', password: 'password123' });

    expectError(
      await errorOf(service.login({ email: 'pending@dealgo.vn', password: 'password123' })),
      401,
      'AUTH_INVALID_CREDENTIALS',
    );
  });

  it('logs in with the same credentials after verification', async () => {
    await signUp('login@dealgo.vn');

    const session = await service.login({ email: 'Login@DealGo.vn', password: 'password123' });

    expect(session.user.email).toBe('login@dealgo.vn');
  });

  it('defaults displayName to the email local-part when omitted', async () => {
    const session = await signUp('rider.one@dealgo.vn');

    expect((await repository.findUserById(session.user.id))?.displayName).toBe('rider.one');
  });

  it('rejects a wrong code and locks the challenge after too many attempts', async () => {
    const challenge = await service.register({ email: 'wrong@dealgo.vn', password: 'password123' });
    const code = mail.signupCodes.at(-1)!.code;
    const wrong = code === '000000' ? '111111' : '000000';

    for (let attempt = 1; attempt < 5; attempt += 1) {
      expectError(
        await errorOf(service.verifyRegistration(challenge.challengeId, wrong)),
        401,
        'AUTH_CODE_INVALID',
      );
    }
    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, wrong)),
      429,
      'AUTH_CODE_LOCKED',
    );
    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, code)),
      429,
      'AUTH_CODE_LOCKED',
    );
    expect(await repository.findUserByEmail('wrong@dealgo.vn')).toBeNull();
  });

  it('rejects an expired code', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const challenge = await service.register({ email: 'late@dealgo.vn', password: 'password123' });
    const code = mail.signupCodes.at(-1)!.code;

    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_TTL_MS + 1);

    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, code)),
      401,
      'AUTH_CODE_EXPIRED',
    );
    expect(await repository.findUserByEmail('late@dealgo.vn')).toBeNull();
  });

  it('resends a new code after the cooldown and invalidates the old one', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const challenge = await service.register({ email: 'again@dealgo.vn', password: 'password123' });
    const firstCode = mail.signupCodes.at(-1)!.code;

    expectError(
      await errorOf(service.resendRegistration(challenge.challengeId)),
      429,
      'AUTH_OTP_RESEND_COOLDOWN',
    );

    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
    const resent = await service.resendRegistration(challenge.challengeId);
    expect(resent.challengeId).toBe(challenge.challengeId);
    expect(mail.signupCodes).toHaveLength(2);
    const secondCode = mail.signupCodes.at(-1)!.code;

    if (firstCode !== secondCode) {
      expectError(
        await errorOf(service.verifyRegistration(challenge.challengeId, firstCode)),
        401,
        'AUTH_CODE_INVALID',
      );
    }
    const session = await service.verifyRegistration(challenge.challengeId, secondCode);
    expect(session.user.email).toBe('again@dealgo.vn');
  });

  it('keeps wrong attempts across resends and refuses to resend a locked challenge', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const challenge = await service.register({ email: 'sticky@dealgo.vn', password: 'password123' });
    const wrongFor = (code: string) => (code === '000000' ? '111111' : '000000');

    for (let attempt = 1; attempt < EMAIL_SIGNUP_MAX_ATTEMPTS; attempt += 1) {
      expectError(
        await errorOf(
          service.verifyRegistration(challenge.challengeId, wrongFor(mail.signupCodes.at(-1)!.code)),
        ),
        401,
        'AUTH_CODE_INVALID',
      );
    }
    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
    await service.resendRegistration(challenge.challengeId);
    const freshCode = mail.signupCodes.at(-1)!.code;
    expect((await repository.findEmailSignupChallenge(challenge.challengeId))?.attemptCount).toBe(
      EMAIL_SIGNUP_MAX_ATTEMPTS - 1,
    );

    // One more wrong guess reaches the per-challenge total, even with a fresh code.
    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, wrongFor(freshCode))),
      429,
      'AUTH_CODE_LOCKED',
    );
    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, freshCode)),
      429,
      'AUTH_CODE_LOCKED',
    );
    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
    expectError(
      await errorOf(service.resendRegistration(challenge.challengeId)),
      429,
      'AUTH_CODE_LOCKED',
    );
    expect(mail.signupCodes).toHaveLength(2);

    // Starting over is the way out, and it counts toward the hourly cap.
    const restart = await service.register({ email: 'sticky@dealgo.vn', password: 'password123' });
    expect(restart.challengeId).not.toBe(challenge.challengeId);
    expect(
      await repository.countEmailSignupChallengesSince('sticky@dealgo.vn', new Date(0)),
    ).toBe(2);
    const session = await service.verifyRegistration(
      restart.challengeId,
      mail.signupCodes.at(-1)!.code,
    );
    expect(session.user.email).toBe('sticky@dealgo.vn');
  });

  it('stops resending after the per-challenge send limit', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const challenge = await service.register({ email: 'limit@dealgo.vn', password: 'password123' });
    for (let send = 1; send < EMAIL_SIGNUP_MAX_SENDS; send += 1) {
      vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
      await service.resendRegistration(challenge.challengeId);
    }
    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);

    expectError(
      await errorOf(service.resendRegistration(challenge.challengeId)),
      429,
      'AUTH_OTP_RESEND_LIMIT',
    );
    expect(mail.signupCodes).toHaveLength(EMAIL_SIGNUP_MAX_SENDS);
  });

  it('answers an existing email like a new one, notifies the owner and never verifies', async () => {
    const owner = await signUp('dup@dealgo.vn', 'password123');
    mail.signupCodes.length = 0;

    const challenge = await service.register({ email: 'DUP@dealgo.vn', password: 'password456' });

    expect(challenge).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    expect(mail.signupCodes).toHaveLength(0);
    expect(mail.signupAccountExists).toEqual(['dup@dealgo.vn']);
    for (const guess of ['000000', '123456']) {
      expectError(
        await errorOf(service.verifyRegistration(challenge.challengeId, guess)),
        401,
        'AUTH_CODE_INVALID',
      );
    }
    const login = await service.login({ email: 'dup@dealgo.vn', password: 'password123' });
    expect(login.user.id).toBe(owner.user.id);
  });

  it('returns EMAIL_IN_USE when the address is taken between challenge and verify', async () => {
    const challenge = await service.register({ email: 'race@dealgo.vn', password: 'password123' });
    const code = mail.signupCodes.at(-1)!.code;
    await repository.createUser({ email: 'race@dealgo.vn', phone: null, displayName: 'Other' });

    expectError(
      await errorOf(service.verifyRegistration(challenge.challengeId, code)),
      409,
      'EMAIL_IN_USE',
    );
  });

  it('limits sign-up challenges per email per hour', async () => {
    for (let attempt = 0; attempt < EMAIL_SIGNUP_MAX_PER_HOUR; attempt += 1) {
      await service.register({ email: 'flood@dealgo.vn', password: 'password123' });
    }

    expectError(
      await errorOf(service.register({ email: 'flood@dealgo.vn', password: 'password123' })),
      429,
      'AUTH_OTP_RATE_LIMITED',
    );
  });

  it('fails with 503 and creates nothing usable when the email cannot be sent', async () => {
    const offline = new EmailPasswordAuthService(
      repository,
      sessions,
      passwords,
      authMethods,
      new UnavailableMailSender(),
      config,
    );

    expectError(
      await errorOf(offline.register({ email: 'nomail@dealgo.vn', password: 'password123' })),
      503,
      'EMAIL_DELIVERY_FAILED',
    );
    expect(await repository.findUserByEmail('nomail@dealgo.vn')).toBeNull();
  });

  it('answers before the code is mailed, so SMTP latency never blocks sign-up', async () => {
    let release: (() => void) | undefined;
    const pending = new Promise<void>((resolve) => {
      release = resolve;
    });
    const slow = Object.assign(new MockMailSender('test'), {
      sendSignupCode: async () => {
        await pending;
      },
    });
    const service = new EmailPasswordAuthService(
      repository,
      sessions,
      passwords,
      authMethods,
      slow,
      config,
    );

    const challenge = await service.register({ email: 'fast@dealgo.vn', password: 'password123' });

    expect(challenge.challengeId).toEqual(expect.any(String));
    expect(await repository.findEmailSignupChallenge(challenge.challengeId)).not.toBeNull();
    release?.();
  });

  it('keeps the challenge when the provider refuses the address after the answer', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const rejecting = new EmailPasswordAuthService(
      repository,
      sessions,
      passwords,
      authMethods,
      Object.assign(new MockMailSender('test'), {
        sendSignupCode: async () => {
          throw new MailDeliveryError('rejected', 'smtp', '555');
        },
      }),
      config,
    );

    const challenge = await rejecting.register({ email: 'bad@dealgo.vn', password: 'password123' });

    expect(challenge).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    await vi.waitFor(() => expect(warn).toHaveBeenCalled());
    expect(await repository.findUserByEmail('bad@dealgo.vn')).toBeNull();
    warn.mockRestore();
  });

  it('rejects non-ASCII email local parts at validation', async () => {
    const { validate } = await import('class-validator');
    const { plainToInstance } = await import('class-transformer');
    const { EmailVerificationDto } = await import('./auth.dto.js');
    expect(await validate(plainToInstance(EmailVerificationDto, { email: 'ái@gmail.com' }))).not.toHaveLength(0);
    expect(await validate(plainToInstance(EmailVerificationDto, { email: 'ai@gmail.com' }))).toHaveLength(0);
  });

  async function createLegacyUser(email: string, password = 'password123') {
    const legacy = await repository.createUser({ email, phone: null, displayName: 'Legacy' });
    await repository.saveCustomerCredential(legacy.id, await passwords.hash(password));
    return legacy;
  }

  async function activationChallengeOf(promise: Promise<unknown>) {
    const error = await errorOf(promise);
    expectError(error, 403, 'AUTH_EMAIL_NOT_VERIFIED');
    const details = (error.getResponse() as { details?: Record<string, string> }).details;
    expect(details).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    return details!;
  }

  it('mails an activation code when a never-verified account logs in with the right password', async () => {
    const legacy = await createLegacyUser('legacy@dealgo.vn');

    expectError(
      await errorOf(service.login({ email: 'legacy@dealgo.vn', password: 'wrong-password' })),
      401,
      'AUTH_INVALID_CREDENTIALS',
    );
    expect(mail.signupCodes).toHaveLength(0);

    const details = await activationChallengeOf(
      service.login({ email: 'Legacy@DealGo.vn', password: 'password123' }),
    );
    const delivered = mail.signupCodes.at(-1)!;
    expect(delivered).toMatchObject({ email: 'legacy@dealgo.vn', purpose: 'activation' });
    expect(await repository.findEmailSignupChallenge(details.challengeId)).toMatchObject({
      purpose: 'ACTIVATE_EXISTING',
      userId: legacy.id,
      passwordHash: null,
    });
    expect((await repository.findUserById(legacy.id))?.emailVerifiedAt).toBeNull();

    const session = await service.verifyRegistration(details.challengeId, delivered.code);

    expect(session.user.id).toBe(legacy.id);
    expect((await repository.findUserById(legacy.id))?.emailVerifiedAt).toBeInstanceOf(Date);
    expect(await repository.listGrants(legacy.id)).toEqual([
      expect.objectContaining({ role: 'CUSTOMER', status: 'ACTIVE' }),
    ]);
    const login = await service.login({ email: 'legacy@dealgo.vn', password: 'password123' });
    expect(login.user.id).toBe(legacy.id);
    expectError(
      await errorOf(service.verifyRegistration(details.challengeId, delivered.code)),
      401,
      'AUTH_CODE_INVALID',
    );
  });

  it('reuses the activation challenge inside the cooldown and resends through the same endpoint', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    const legacy = await createLegacyUser('repeat@dealgo.vn');
    const login = () => service.login({ email: 'repeat@dealgo.vn', password: 'password123' });

    const first = await activationChallengeOf(login());
    const second = await activationChallengeOf(login());
    expect(second.challengeId).toBe(first.challengeId);
    expect(mail.signupCodes).toHaveLength(1);

    expectError(
      await errorOf(service.resendRegistration(first.challengeId)),
      429,
      'AUTH_OTP_RESEND_COOLDOWN',
    );
    vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
    await service.resendRegistration(first.challengeId);
    expect(mail.signupCodes).toHaveLength(2);
    expect(mail.signupCodes.at(-1)!.purpose).toBe('activation');

    const session = await service.verifyRegistration(
      first.challengeId,
      mail.signupCodes.at(-1)!.code,
    );
    expect(session.user.id).toBe(legacy.id);
  });

  it('keeps an existing SUSPENDED customer grant when activating', async () => {
    const legacy = await createLegacyUser('suspended@dealgo.vn');
    await repository.insertGrant(legacy.id, 'CUSTOMER', 'SUSPENDED');

    const details = await activationChallengeOf(
      service.login({ email: 'suspended@dealgo.vn', password: 'password123' }),
    );
    await service.verifyRegistration(details.challengeId, mail.signupCodes.at(-1)!.code);

    expect(await repository.listGrants(legacy.id)).toEqual([
      expect.objectContaining({ role: 'CUSTOMER', status: 'SUSPENDED' }),
    ]);
  });

  it('applies the hourly cap to activation codes', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    await createLegacyUser('capped@dealgo.vn');
    const login = () => service.login({ email: 'capped@dealgo.vn', password: 'password123' });

    for (let attempt = 0; attempt < EMAIL_SIGNUP_MAX_PER_HOUR; attempt += 1) {
      await activationChallengeOf(login());
      vi.setSystemTime(Date.now() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS);
    }

    expectError(await errorOf(login()), 429, 'AUTH_OTP_RATE_LIMITED');
    expect(mail.signupCodes).toHaveLength(EMAIL_SIGNUP_MAX_PER_HOUR);
  });

  it('does not activate when the account email changed after the code was sent', async () => {
    const legacy = await createLegacyUser('moved@dealgo.vn');
    const details = await activationChallengeOf(
      service.login({ email: 'moved@dealgo.vn', password: 'password123' }),
    );
    await repository.setEmailVerified(legacy.id, 'elsewhere@dealgo.vn', new Date());

    expectError(
      await errorOf(service.verifyRegistration(details.challengeId, mail.signupCodes.at(-1)!.code)),
      401,
      'AUTH_CODE_INVALID',
    );
  });

  it('returns the same AUTH_INVALID_CREDENTIALS for missing user and wrong password', async () => {
    await signUp('known@dealgo.vn');

    const missing = await errorOf(
      service.login({ email: 'missing@dealgo.vn', password: 'password123' }),
    );
    const wrong = await errorOf(service.login({ email: 'known@dealgo.vn', password: 'wrong-password' }));

    for (const error of [missing, wrong]) {
      expect(error.getStatus()).toBe(401);
      expect(error.getResponse()).toMatchObject({
        errorCode: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid email or password',
      });
    }
  });

  it('rejects register, verify, resend and login when EMAIL_LOGIN_IDENTIFIER is disabled', async () => {
    const challenge = await service.register({ email: 'blocked@dealgo.vn', password: 'password123' });
    await authMethods.setEnabled(
      'EMAIL_LOGIN_IDENTIFIER',
      false,
      'disable email password',
      '11111111-1111-1111-1111-111111111111',
    );

    const sentBefore = mail.signupCodes.length;
    for (const attempt of [
      service.register({ email: 'blocked@dealgo.vn', password: 'password123' }),
      service.verifyRegistration(challenge.challengeId, mail.signupCodes.at(-1)!.code),
      service.resendRegistration(challenge.challengeId),
      service.login({ email: 'blocked@dealgo.vn', password: 'password123' }),
    ]) {
      const error = await errorOf(attempt);
      // Generic 404, same as an unknown route: nothing names the method or says it is off.
      expect(error.getStatus()).toBe(404);
      expect(JSON.stringify(error.getResponse())).not.toMatch(/email|disabled|method/i);
    }
    expect(mail.signupCodes).toHaveLength(sentBefore);
  });

  describe('AUTH_EMAIL_VERIFICATION_REQUIRED', () => {
    function withToggle(required: boolean | 'throws') {
      const settings = {
        getBoolean: async () => {
          if (required === 'throws') throw new Error('settings down');
          return required;
        },
      } as unknown as PlatformSettingsService;
      return new EmailPasswordAuthService(
        repository, sessions, passwords, authMethods, mail, config, undefined, settings,
      );
    }

    it('uses a random code, never a fixed one, when verification is required', async () => {
      const on = withToggle(true);
      await on.register({ email: 'a1@dealgo.vn', password: 'password123' });
      await on.register({ email: 'a2@dealgo.vn', password: 'password123' });
      const codes = mail.signupCodes.map((c) => c.code);
      expect(codes).toHaveLength(2);
      expect(codes).not.toContain('000000');
      expect(await repository.findUserByEmail('a1@dealgo.vn')).toBeNull();
    });

    it('off: signs up at once without mail; email stays unverified; login works', async () => {
      const off = withToggle(false);
      const result = await off.register({ email: 'Bo@DealGo.vn', password: 'password123' });
      expect(mail.signupCodes).toHaveLength(0);
      expect(result).toMatchObject({ verificationRequired: false });
      expect('session' in result && result.session.accessToken).toBeTruthy();
      expect(result.challengeId).toEqual(expect.any(String));
      const user = await repository.findUserByEmail('bo@dealgo.vn');
      expect(user?.emailVerifiedAt).toBeNull();
      // The placeholder challenge can never be verified or resent.
      expectError(await errorOf(off.verifyRegistration(result.challengeId, '000000')), 401, 'AUTH_CODE_INVALID');
      expectError(await errorOf(off.resendRegistration(result.challengeId)), 401, 'AUTH_CODE_INVALID');
      const login = await off.login({ email: 'bo@dealgo.vn', password: 'password123' });
      expect(login.accessToken).toBeTruthy();
    });

    it('off: an existing address keeps the private notice path (no account leak)', async () => {
      await signUp('cu@dealgo.vn');
      const off = withToggle(false);
      const result = await off.register({ email: 'cu@dealgo.vn', password: 'other12345' });
      expect(result).not.toHaveProperty('session');
    });

    it('turning it back on requires the code again at login for unverified accounts', async () => {
      await withToggle(false).register({ email: 'di@dealgo.vn', password: 'password123' });
      const error = await errorOf(withToggle(true).login({ email: 'di@dealgo.vn', password: 'password123' }));
      expectError(error, 403, 'AUTH_EMAIL_NOT_VERIFIED');
    });

    it('defaults to required when settings cannot be read', async () => {
      await expect(withToggle('throws').verificationRequired()).resolves.toBe(true);
    });
  });

  describe('device registration control', () => {
    it('records device registration on successful verified sign-up', async () => {
      const challenge = await service.register(
        { email: 'dev1@dealgo.vn', password: 'password123' },
        { deviceId: 'device-123' },
      );
      const code = mail.signupCodes.find((c) => c.email === 'dev1@dealgo.vn')!.code;
      await service.verifyRegistration(challenge.challengeId, code, { deviceId: 'device-123' });

      const count = await repository.countRegistrationsByDeviceId('device-123');
      expect(count).toBe(1);
    });

    it('rejects registration when max accounts per device limit is reached', async () => {
      for (let i = 1; i <= 3; i++) {
        const challenge = await service.register(
          { email: `user${i}@dealgo.vn`, password: 'password123' },
          { deviceId: 'device-capped' },
        );
        const code = mail.signupCodes.find((c) => c.email === `user${i}@dealgo.vn`)!.code;
        await service.verifyRegistration(challenge.challengeId, code, { deviceId: 'device-capped' });
      }

      const error = await errorOf(
        service.register(
          { email: 'user4@dealgo.vn', password: 'password123' },
          { deviceId: 'device-capped' },
        ),
      );
      expectError(error, 429, 'AUTH_DEVICE_REGISTRATION_LIMIT');
    });

    it('allows existing user to login from capped device', async () => {
      for (let i = 1; i <= 3; i++) {
        const challenge = await service.register(
          { email: `user${i}@dealgo.vn`, password: 'password123' },
          { deviceId: 'device-full' },
        );
        const code = mail.signupCodes.find((c) => c.email === `user${i}@dealgo.vn`)!.code;
        await service.verifyRegistration(challenge.challengeId, code, { deviceId: 'device-full' });
      }

      const session = await service.login(
        { email: 'user1@dealgo.vn', password: 'password123' },
        { deviceId: 'device-full' },
      );
      expect(session.accessToken).toBeTruthy();
    });
  });
});
