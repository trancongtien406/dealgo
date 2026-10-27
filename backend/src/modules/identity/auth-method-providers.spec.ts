import { HttpException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import { MockMailSender, UnavailableMailSender } from '../../integrations/email/index.js';
import { MockSmsSender, UnavailableSmsSender } from '../../integrations/sms/index.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import {
  AuthMethodProviderBootCheck,
  authMethodProviderAvailable,
  enabledMethodsWithoutProvider,
  type AuthMethodProviderStatus,
} from './auth-method-providers.js';
import type { AuthMethodName } from './auth-method.constants.js';
import { MemoryAuthMethodPolicyRepository } from './auth-method.repository.js';

const webauthn = { WEBAUTHN_RP_ID: 'dealgo.vn', WEBAUTHN_RP_NAME: 'DealGo', WEBAUTHN_ORIGIN: 'https://dealgo.vn' };
const actor = '11111111-1111-1111-1111-111111111111';
const status = (ready: Partial<Record<AuthMethodName, boolean>>) =>
  ({ isAvailable: (method: AuthMethodName) => ready[method] ?? true }) as AuthMethodProviderStatus;
const config = (nodeEnv: string) => ({ get: () => nodeEnv }) as never;

describe('authMethodProviderAvailable', () => {
  it('reflects SMS, mail and WebAuthn configuration', () => {
    const ok = { sms: new MockSmsSender('test'), mail: new MockMailSender('test'), env: webauthn };
    const none = { sms: new UnavailableSmsSender(), mail: new UnavailableMailSender(), env: { ...webauthn, WEBAUTHN_ORIGIN: undefined } };
    for (const method of ['PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER', 'PASSKEY'] as const) {
      expect(authMethodProviderAvailable(method, ok as never)).toBe(true);
      expect(authMethodProviderAvailable(method, none as never)).toBe(false);
    }
  });
});

describe('auth method provider guards', () => {
  it('refuses enabling a method without a provider (409) but allows disabling it', async () => {
    const repo = new MemoryAuthMethodPolicyRepository();
    const service = new AuthMethodPolicyService(repo, status({ PHONE_SMS: false }));
    await service.setEnabled('PHONE_SMS', false, 'launch email + passkey only', actor);
    const error = await service.setEnabled('PHONE_SMS', true, 're-enable', actor).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpException);
    expect((error as HttpException).getStatus()).toBe(409);
    expect((error as HttpException).getResponse()).toMatchObject({ errorCode: 'AUTH_METHOD_PROVIDER_UNAVAILABLE' });
    expect((await service.list()).find((row) => row.method === 'PHONE_SMS')).toMatchObject({
      enabled: false,
      providerReady: false,
    });
  });

  it('blocks production boot only while an enabled method lacks its provider', async () => {
    const repo = new MemoryAuthMethodPolicyRepository();
    const providers = status({ PHONE_SMS: false });
    expect(await enabledMethodsWithoutProvider(repo, providers)).toEqual(['PHONE_SMS']);
    await expect(new AuthMethodProviderBootCheck(repo, providers, config('production')).onApplicationBootstrap()).rejects.toThrow(
      /PHONE_SMS.*auth-methods -- disable/,
    );
    await expect(new AuthMethodProviderBootCheck(repo, providers, config('development')).onApplicationBootstrap()).resolves.toBeUndefined();

    await repo.setEnabled({ method: 'PHONE_SMS', enabled: false, updatedByUserId: actor, reason: 'off' } as never);
    await expect(new AuthMethodProviderBootCheck(repo, providers, config('production')).onApplicationBootstrap()).resolves.toBeUndefined();
  });
});
