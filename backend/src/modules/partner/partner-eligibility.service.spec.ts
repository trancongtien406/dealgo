import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { PartnerEligibilityService } from './partner-eligibility.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';

function configFor(
  nodeEnv: AppEnv['NODE_ENV'],
  bypass?: boolean,
): ConfigService<AppEnv, true> {
  return {
    get(key: keyof AppEnv) {
      if (key === 'NODE_ENV') {
        return nodeEnv;
      }
      if (key === 'PARTNER_ELIGIBILITY_BYPASS') {
        return bypass;
      }
      return undefined;
    },
  } as ConfigService<AppEnv, true>;
}

describe('PartnerEligibilityService', () => {
  it('bypasses KYC in test after ACTIVE grant by default', async () => {
    const identity = new MemoryIdentityRepository();
    const partners = new MemoryPartnerRepository();
    const user = await identity.createUser({
      email: null,
      phone: '+84901110001',
      displayName: 'Driver',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    const service = new PartnerEligibilityService(identity, partners, configFor('test'));

    await expect(service.requireEligibleDriver(user.id)).resolves.toBeUndefined();
  });

  it('requires APPROVED KYC when bypass is disabled', async () => {
    const identity = new MemoryIdentityRepository();
    const partners = new MemoryPartnerRepository();
    const user = await identity.createUser({
      email: null,
      phone: '+84901110002',
      displayName: 'Driver',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    const service = new PartnerEligibilityService(
      identity,
      partners,
      configFor('production', false),
    );

    await expect(service.requireEligibleDriver(user.id)).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_KYC_REQUIRED' },
    });

    await partners.upsertSubmit({
      id: crypto.randomUUID(),
      userId: user.id,
      role: 'DRIVER',
      metadata: { licenseNumber: 'B2' },
      documents: [],
      now: new Date(),
    });
    await partners.review({
      id: (await partners.findByUserAndRole(user.id, 'DRIVER'))!.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: user.id,
      now: new Date(),
    });

    await expect(service.requireEligibleDriver(user.id)).resolves.toBeUndefined();
  });
});
