import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { RoleGrantsService } from './role-grants.service.js';

function configFor(nodeEnv: AppEnv['NODE_ENV']): ConfigService<AppEnv, true> {
  return {
    get(key: keyof AppEnv) {
      if (key === 'NODE_ENV') {
        return nodeEnv;
      }
      return undefined;
    },
  } as ConfigService<AppEnv, true>;
}

describe('RoleGrantsService', () => {
  it('auto-approves requestable roles in development and test', async () => {
    for (const nodeEnv of ['development', 'test'] as const) {
      const repository = new MemoryIdentityRepository();
      const user = await repository.createUser({
        email: null,
        phone: `+8490${nodeEnv === 'test' ? '1111111' : '2222222'}`,
        displayName: 'Rider',
      });
      const service = new RoleGrantsService(repository, configFor(nodeEnv));

      const customer = await service.requestRole(user.id, 'CUSTOMER');
      const driver = await service.requestRole(user.id, 'DRIVER');
      const merchant = await service.requestRole(user.id, 'MERCHANT');

      expect(customer.status).toBe('ACTIVE');
      expect(driver.status).toBe('ACTIVE');
      expect(merchant.status).toBe('ACTIVE');
    }
  });

  it('keeps production role requests pending until ops review', async () => {
    const repository = new MemoryIdentityRepository();
    const user = await repository.createUser({
      email: null,
      phone: '+84903333333',
      displayName: 'Rider',
    });
    const service = new RoleGrantsService(repository, configFor('production'));

    const driver = await service.requestRole(user.id, 'DRIVER');
    expect(driver).toEqual({
      id: expect.any(String),
      role: 'DRIVER',
      status: 'PENDING',
    });

    const approved = await service.approve(driver.id);
    expect(approved.status).toBe('ACTIVE');

    const merchant = await service.requestRole(user.id, 'MERCHANT');
    const rejected = await service.reject(merchant.id);
    expect(rejected.status).toBe('SUSPENDED');
  });

  it('does not let a user re-open a suspended grant in any environment', async () => {
    for (const nodeEnv of ['development', 'test', 'production'] as const) {
      const repository = new MemoryIdentityRepository();
      const user = await repository.createUser({
        email: null,
        phone: `+8490777${nodeEnv.length}${nodeEnv.length}${nodeEnv.length}`,
        displayName: 'Rider',
      });
      const suspended = await repository.insertGrant(
        user.id,
        'DRIVER',
        'SUSPENDED',
      );
      const service = new RoleGrantsService(repository, configFor(nodeEnv));

      await expect(
        service.requestRole(user.id, 'DRIVER'),
      ).rejects.toMatchObject({
        status: 403,
        response: { errorCode: 'ROLE_GRANT_SUSPENDED' },
      });
      expect(await repository.findGrantById(suspended.id)).toMatchObject({
        status: 'SUSPENDED',
      });
    }
  });

  it('rejects review of non-pending grants', async () => {
    const repository = new MemoryIdentityRepository();
    const user = await repository.createUser({
      email: null,
      phone: '+84904444444',
      displayName: 'Rider',
    });
    const grant = await repository.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    const service = new RoleGrantsService(repository, configFor('production'));

    await expect(service.approve(grant.id)).rejects.toMatchObject({
      response: { errorCode: 'ROLE_GRANT_NOT_PENDING' },
    });
  });
});
