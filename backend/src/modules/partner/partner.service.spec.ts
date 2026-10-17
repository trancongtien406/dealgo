import { describe, expect, it } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { MockKycStorage } from '../../integrations/object-storage/mock-kyc-storage.js';
import type { AppEnv } from '../../platform/config/env.js';

describe('PartnerService', () => {
  const createService = async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const storage = new MockKycStorage();
    const config = {
      get: (key: string) => (key === 'NODE_ENV' ? 'test' : undefined),
    } as unknown as ConfigService<AppEnv, true>;

    const user = await identity.createUser({
      email: 'driver@dealgo.vn',
      phone: '+84988776655',
      displayName: 'Tran Tai Xe',
    });

    const service = new PartnerService(partners, identity, storage, config);
    return { service, partners, identity, user };
  };

  it('submits a partner application and lists it for user', async () => {
    const { service, user } = await createService();

    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehiclePlate: '51F-12345', vehicleModel: 'Honda Wave' },
    });

    expect(app.id).toBeDefined();
    expect(app.role).toBe('DRIVER');
    expect(app.status).toBe('SUBMITTED');

    const mine = await service.listMine(user.id);
    expect(mine.applications).toHaveLength(1);
    expect(mine.applications[0].id).toBe(app.id);
  });

  it('approves an application and activates role grant', async () => {
    const { service, identity, user } = await createService();

    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehiclePlate: '51F-12345' },
    });

    const reviewed = await service.approve(app.id, 'ops-approver');

    expect(reviewed.status).toBe('APPROVED');
    expect(reviewed.reviewedBy).toBe('ops-approver');

    // Check that identity role grant is ACTIVE
    const directory = await identity.findUserDirectory(user.id);
    const driverGrant = directory?.grants.find((g) => g.role === 'DRIVER');
    expect(driverGrant?.status).toBe('ACTIVE');
  });

  it('rejects an application and suspends role grant', async () => {
    const { service, identity, user } = await createService();

    const app = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: { storeName: 'Quán ăn chưa đăng ký' },
    });

    const reviewed = await service.reject(
      app.id,
      'ops-approver',
      'Thiếu giấy phép an toàn vệ sinh thực phẩm',
    );

    expect(reviewed.status).toBe('REJECTED');
    expect(reviewed.reason).toContain('Thiếu giấy phép');

    const directory = await identity.findUserDirectory(user.id);
    const merchantGrant = directory?.grants.find((g) => g.role === 'MERCHANT');
    expect(merchantGrant?.status).toBe('SUSPENDED');
  });
});
