import { HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { beforeEach, describe, expect, it } from 'vitest';
import type { AppEnv } from '../../platform/config/env.js';
import type { SmsSender } from '../../integrations/sms/sms-sender.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { MemoryAuthMethodPolicyRepository } from './auth-method.repository.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { PhoneAuthService } from './phone-auth.service.js';
import { SessionService } from './session.service.js';

class MockSmsSender implements SmsSender {
  sent: Array<{ phone: string; code: string }> = [];

  async sendOtp(phone: string, code: string): Promise<void> {
    this.sent.push({ phone, code });
  }
}

async function errorOf(promise: Promise<unknown>): Promise<HttpException> {
  const error = await promise.catch((err: unknown) => err);
  expect(error).toBeInstanceOf(HttpException);
  return error as HttpException;
}

function expectError(error: HttpException, status: number, errorCode: string) {
  expect(error.getStatus()).toBe(status);
  expect(error.getResponse()).toMatchObject({ errorCode });
}

describe('PhoneAuthService device registration control', () => {
  let repository: MemoryIdentityRepository;
  let authMethods: AuthMethodPolicyService;
  let sms: MockSmsSender;
  let config: ConfigService<AppEnv, true>;
  let sessions: SessionService;
  let service: PhoneAuthService;

  beforeEach(() => {
    repository = new MemoryIdentityRepository();
    authMethods = new AuthMethodPolicyService(new MemoryAuthMethodPolicyRepository());
    sms = new MockSmsSender();

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
    service = new PhoneAuthService(repository, sms, sessions, config, authMethods);
  });

  it('records device registration when new phone registers and verifies OTP', async () => {
    const challenge = await service.createChallenge('+84901000001', { deviceId: 'phone-device-1' });
    const code = sms.sent[0].code;
    const session = await service.verify(challenge.challengeId, code, { deviceId: 'phone-device-1' });

    expect(session.accessToken).toBeTruthy();
    const count = await repository.countRegistrationsByDeviceId('phone-device-1');
    expect(count).toBe(1);
  });

  it('blocks registration when a device reaches MAX_ACCOUNTS_PER_DEVICE (3)', async () => {
    for (let i = 1; i <= 3; i++) {
      const phone = `+8490100000${i}`;
      const challenge = await service.createChallenge(phone, { deviceId: 'device-max' });
      const code = sms.sent.find((s) => s.phone === phone)!.code;
      await service.verify(challenge.challengeId, code, { deviceId: 'device-max' });
    }

    const count = await repository.countRegistrationsByDeviceId('device-max');
    expect(count).toBe(3);

    // 4th phone challenge creation from same device should be blocked
    const errorCreate = await errorOf(
      service.createChallenge('+84901000099', { deviceId: 'device-max' }),
    );
    expectError(errorCreate, 429, 'AUTH_DEVICE_REGISTRATION_LIMIT');
  });

  it('allows an existing verified phone user to sign in from a capped device', async () => {
    // 3 users register on device-capped
    for (let i = 1; i <= 3; i++) {
      const phone = `+8490200000${i}`;
      const challenge = await service.createChallenge(phone, { deviceId: 'device-capped' });
      const code = sms.sent.find((s) => s.phone === phone)!.code;
      await service.verify(challenge.challengeId, code, { deviceId: 'device-capped' });
    }

    // Now user 1 logs in again from the same device: challenge + verify should succeed
    const challenge2 = await service.createChallenge('+84902000001', { deviceId: 'device-capped' });
    const code2 = sms.sent.filter((s) => s.phone === '+84902000001').pop()!.code;
    const session = await service.verify(challenge2.challengeId, code2, { deviceId: 'device-capped' });
    expect(session.accessToken).toBeTruthy();

    // Count should still remain 3
    const count = await repository.countRegistrationsByDeviceId('device-capped');
    expect(count).toBe(3);
  });
});

