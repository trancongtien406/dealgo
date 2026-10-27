import { ConfigService } from '@nestjs/config';
import { loadEnv, type AppEnv } from '../../platform/config/env.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { PartnerEligibilityService } from './partner-eligibility.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';

function configFor(
  nodeEnv: AppEnv['NODE_ENV'],
  opts?: { bypass?: boolean; carExtraDocs?: boolean; deployEnv?: AppEnv['DEPLOY_ENV'] },
): ConfigService<AppEnv, true> {
  return {
    get(key: keyof AppEnv) {
      if (key === 'NODE_ENV') {
        return nodeEnv;
      }
      if (key === 'DEPLOY_ENV') {
        return opts?.deployEnv;
      }
      if (key === 'PARTNER_ELIGIBILITY_BYPASS') {
        return opts?.bypass;
      }
      if (key === 'PARTNER_CAR_KYC_EXTRA_DOCS') {
        return opts?.carExtraDocs;
      }
      return undefined;
    },
  } as ConfigService<AppEnv, true>;
}

describe('PartnerEligibilityService', () => {
  it('Bypass defaults on only for local builds; staging/production stay strict', () => {
    const svc = (nodeEnv: AppEnv['NODE_ENV'], deployEnv?: AppEnv['DEPLOY_ENV'], bypass?: boolean) =>
      new PartnerEligibilityService(
        new MemoryIdentityRepository(),
        new MemoryPartnerRepository(),
        configFor(nodeEnv, { deployEnv, bypass }),
      ).bypassEnabled();
    expect(svc('development')).toBe(true);
    expect(svc('development', 'staging')).toBe(false);
    expect(svc('production')).toBe(false);
    expect(svc('development', 'staging', true)).toBe(true);
    expect(() => loadEnv({ NODE_ENV: 'test', DEPLOY_ENV: 'production', PARTNER_ELIGIBILITY_BYPASS: 'true' })).toThrow(
      /PARTNER_ELIGIBILITY_BYPASS/,
    );
  });

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
      configFor('production', { bypass: false }),
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

  it('fail-closes Car offer/eligibility when gate on and VEHICLE_INSURANCE missing', async () => {
    const identity = new MemoryIdentityRepository();
    const partners = new MemoryPartnerRepository();
    const user = await identity.createUser({
      email: null,
      phone: '+84901110003',
      displayName: 'Car Driver',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    await partners.upsertSubmit({
      id: crypto.randomUUID(),
      userId: user.id,
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
      documents: [
        {
          kind: 'VEHICLE_REG',
          label: 'reg',
          contentType: 'image/jpeg',
          sizeBytes: 1,
          key: 'k',
          uploadedAt: new Date().toISOString(),
        },
      ],
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

    const gated = new PartnerEligibilityService(
      identity,
      partners,
      configFor('production', { bypass: false, carExtraDocs: true }),
    );
    await expect(gated.requireEligibleDriver(user.id)).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_KYC_REQUIRED' },
    });

    const ungated = new PartnerEligibilityService(
      identity,
      partners,
      configFor('production', { bypass: false, carExtraDocs: false }),
    );
    await expect(ungated.requireEligibleDriver(user.id)).resolves.toBeUndefined();
  });

  it('driverVehicleClassCode fail-closes without application / without APPROVED / without class', async () => {
    const identity = new MemoryIdentityRepository();
    const partners = new MemoryPartnerRepository();
    const user = await identity.createUser({
      email: null,
      phone: '+84901110004',
      displayName: 'No Class',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    const gated = new PartnerEligibilityService(
      identity,
      partners,
      configFor('production', { bypass: false }),
    );
    await expect(gated.driverVehicleClassCode(user.id)).resolves.toBeNull();

    await partners.upsertSubmit({
      id: crypto.randomUUID(),
      userId: user.id,
      role: 'DRIVER',
      metadata: { licenseNumber: 'B2' },
      documents: [],
      now: new Date(),
    });
    // SUBMITTED but not APPROVED
    await expect(gated.driverVehicleClassCode(user.id)).resolves.toBeNull();

    await partners.review({
      id: (await partners.findByUserAndRole(user.id, 'DRIVER'))!.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: user.id,
      now: new Date(),
    });
    // APPROVED but still no vehicleClassCode
    await expect(gated.driverVehicleClassCode(user.id)).resolves.toBeNull();
  });

  it('driverVehicleClassCode returns explicit catalog class when APPROVED', async () => {
    const identity = new MemoryIdentityRepository();
    const partners = new MemoryPartnerRepository();
    const user = await identity.createUser({
      email: null,
      phone: '+84901110005',
      displayName: 'Bike Driver',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');
    await partners.upsertSubmit({
      id: crypto.randomUUID(),
      userId: user.id,
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE' },
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
    const gated = new PartnerEligibilityService(
      identity,
      partners,
      configFor('production', { bypass: false }),
    );
    await expect(gated.driverVehicleClassCode(user.id)).resolves.toBe('MOTORBIKE');
  });

});
