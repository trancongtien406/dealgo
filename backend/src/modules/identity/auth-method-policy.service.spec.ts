import { HttpException } from '@nestjs/common';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { MemoryAuthMethodPolicyRepository } from './auth-method.repository.js';

describe('AuthMethodPolicyService', () => {
  it('lists all methods enabled by default', async () => {
    const repo = new MemoryAuthMethodPolicyRepository();
    const service = new AuthMethodPolicyService(repo);
    const listed = await service.list();
    expect(listed).toEqual([
      expect.objectContaining({ method: 'PASSKEY', enabled: true, updatedByUserId: null }),
      expect.objectContaining({ method: 'PHONE_SMS', enabled: true, updatedByUserId: null }),
      expect.objectContaining({
        method: 'EMAIL_LOGIN_IDENTIFIER',
        enabled: true,
        updatedByUserId: null,
      }),
    ]);
  });

  it('disables a method and refuses disabling the last enabled one', async () => {
    const repo = new MemoryAuthMethodPolicyRepository();
    const service = new AuthMethodPolicyService(repo);
    const actor = '11111111-1111-1111-1111-111111111111';

    await service.setEnabled('PASSKEY', false, 'ops disable passkey', actor);
    await service.setEnabled('EMAIL_LOGIN_IDENTIFIER', false, 'ops disable email', actor);

    const last = await service.setEnabled('PHONE_SMS', false, 'ops disable phone', actor).catch(
      (error: unknown) => error,
    );
    expect(last).toBeInstanceOf(HttpException);
    expect((last as HttpException).getResponse()).toMatchObject({
      errorCode: 'AUTH_METHOD_LAST_ENABLED',
    });

    const blocked = await service.assertEnabled('PASSKEY').catch((error: unknown) => error);
    expect(blocked).toBeInstanceOf(HttpException);
    expect((blocked as HttpException).getStatus()).toBe(404);
    expect(JSON.stringify((blocked as HttpException).getResponse())).not.toMatch(/passkey|disabled|method/i);
    await expect(service.assertEnabled('PHONE_SMS')).resolves.toBeUndefined();
  });

  it('public list holds only enabled methods and only their names', async () => {
    const repo = new MemoryAuthMethodPolicyRepository();
    const service = new AuthMethodPolicyService(repo);
    const actor = '11111111-1111-1111-1111-111111111111';
    expect(await service.listPublic()).toEqual([
      { method: 'PASSKEY' },
      { method: 'PHONE_SMS' },
      { method: 'EMAIL_LOGIN_IDENTIFIER' },
    ]);

    await service.setEnabled('PHONE_SMS', false, 'sms off', actor);
    await service.setEnabled('EMAIL_LOGIN_IDENTIFIER', false, 'email off', actor);

    expect(await service.listPublic()).toEqual([{ method: 'PASSKEY' }]);
    expect(await service.list()).toHaveLength(3);
  });
});
