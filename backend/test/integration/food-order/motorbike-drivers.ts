import type { INestApplication } from '@nestjs/common';
import type { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../../src/modules/partner/partner.repository.js';

/**
 * FOOD is motorbike-only and fails closed on an unknown vehicle class. These suites grant
 * DRIVER directly, so every DRIVER grant here also gets a MOTORBIKE driver application.
 */
export function seedMotorbikeOnDriverGrant(
  identity: MemoryIdentityRepository,
  app: INestApplication,
): void {
  const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
  const original = identity.insertGrant.bind(identity);
  identity.insertGrant = (async (...args: Parameters<typeof original>) => {
    const result = await original(...args);
    const [userId, role] = args as unknown as [string, string];
    if (role === 'DRIVER' && !(await partners.findByUserAndRole(userId, 'DRIVER'))) {
      await partners.upsertSubmit({
        id: `app-moto-${userId}`,
        userId,
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: [],
        now: new Date(),
      });
    }
    return result;
  }) as typeof identity.insertGrant;
}
