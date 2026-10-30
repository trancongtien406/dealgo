import type { INestApplication } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../src/modules/partner/partner.repository.js';

/**
 * FOOD is motorbike-only and fails closed on an unknown class, so PG suites that grant
 * DRIVER directly also record the driver's vehicle class on a DRIVER application.
 */
export async function seedDriverClass(
  app: INestApplication,
  userId: string,
  vehicleClassCode = 'MOTORBIKE',
): Promise<void> {
  const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
  const existing = await partners.findByUserAndRole(userId, 'DRIVER');
  await partners.upsertSubmit({
    id: existing?.id ?? randomUUID(),
    userId,
    role: 'DRIVER',
    metadata: { ...((existing?.metadata as object) ?? {}), vehicleClassCode },
    documents: [],
    now: new Date(),
  });
}
