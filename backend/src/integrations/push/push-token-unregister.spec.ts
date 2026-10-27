import { describe, expect, it, vi } from 'vitest';
import { PushTokenService } from './push-token.service.js';

describe('PushTokenService.unregister', () => {
  it('removes only that device token (memory mode)', async () => {
    const svc = new PushTokenService({ db: () => null } as never);
    await svc.register('u1', 'token-aaaaaaaa', 'ios');
    await svc.register('u1', 'token-bbbbbbbb', 'android');
    await svc.unregister('u1', 'token-aaaaaaaa');
    expect(await svc.tokensForUser('u1')).toEqual(['token-bbbbbbbb']);
    await expect(svc.unregister('u1', 'missing-token')).resolves.toEqual({
      unregistered: true,
    });
  });
});

describe('PushTokenService device ownership', () => {
  it('moves a device token to the account that signed in on that phone', async () => {
    const svc = new PushTokenService({ db: () => null } as never);
    await svc.register('customer', 'shared-device-token', 'ios');
    await svc.register('driver', 'shared-device-token', 'ios');
    expect(await svc.tokensForUser('customer')).toEqual([]);
    expect(await svc.tokensForUser('driver')).toEqual(['shared-device-token']);
  });

  it('deletes other owners in the same transaction as the upsert (database mode)', async () => {
    const deleteMany = vi.fn().mockReturnValue('delete-op');
    const upsert = vi.fn().mockReturnValue('upsert-op');
    const $transaction = vi.fn().mockResolvedValue([]);
    const db = { pushDeviceToken: { deleteMany, upsert }, $transaction };
    const svc = new PushTokenService({ db: () => db } as never);
    await svc.register('driver', 'shared-device-token', 'ios');
    expect(deleteMany).toHaveBeenCalledWith({
      where: { token: 'shared-device-token', userId: { not: 'driver' } },
    });
    expect($transaction).toHaveBeenCalledWith(['delete-op', 'upsert-op']);
  });

  it('forget drops a dead token for every account', async () => {
    const svc = new PushTokenService({ db: () => null } as never);
    await svc.register('u1', 'dead-token-1', 'ios');
    await svc.forget('dead-token-1');
    expect(await svc.tokensForUser('u1')).toEqual([]);
  });
});

describe('PushTokenService.tokensForUser skipPlatforms', () => {
  it('skips the listed platforms and never returns VoIP tokens', async () => {
    const svc = new PushTokenService({ db: () => null } as never);
    await svc.register('u1', 'token-ios-aaaaaa', 'ios');
    await svc.register('u1', 'token-and-bbbbbb', 'android');
    await svc.register('u1', 'token-voip-cccccc', 'ios-voip');
    expect(await svc.tokensForUser('u1', ['ios'])).toEqual([
      'token-and-bbbbbb',
    ]);
    expect((await svc.tokensForUser('u1')).sort()).toEqual([
      'token-and-bbbbbb',
      'token-ios-aaaaaa',
    ]);
  });
});
