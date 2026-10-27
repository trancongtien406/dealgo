import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../src/modules/partner/partner.repository.js';

type GrantingRepo = {
  insertGrant: (userId: string, role: never, status: never) => Promise<unknown>;
};

/**
 * DG-DEC-VEH-001 made offers / open lists fail closed for drivers without a DRIVER
 * application carrying `vehicleClassCode`. Older HTTP specs only insert the DRIVER grant,
 * so wrap insertGrant to also file a MOTORBIKE application when none exists yet.
 * Specs that need another class keep calling `partners.upsertSubmit` (it overwrites).
 */
export function seedVehicleClassOnDriverGrant(
  app: INestApplication,
  identity: object,
  classCode = 'MOTORBIKE',
): void {
  const repo = identity as GrantingRepo;
  const original = repo.insertGrant.bind(identity);
  repo.insertGrant = (async (userId: string, role: string, status: string) => {
    const result = await original(userId, role as never, status as never);
    if (role === 'DRIVER') {
      const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY, { strict: false });
      if (!(await partners.findByUserAndRole(userId, 'DRIVER'))) {
        await partners.upsertSubmit({
          id: randomUUID(),
          userId,
          role: 'DRIVER',
          metadata: { vehicleClassCode: classCode },
          documents: [],
          now: new Date(),
        });
      }
    }
    return result;
  }) as GrantingRepo['insertGrant'];
}
