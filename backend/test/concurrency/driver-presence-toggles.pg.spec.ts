/** DEC-PROD-023: per-service toggles persist on driver_presence (Postgres). Skips without DATABASE_URL. */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaDriverPresenceRepository } from '../../src/modules/identity/driver-presence-prisma.repository.js';
import { uniqueTestPhone } from './test-phone.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('driver presence toggles (postgres)', () => {
  let db: PrismaClient;

  beforeAll(() => {
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });
  });

  afterAll(async () => {
    await db?.$disconnect();
  });

  it('defaults both services on, stores a switch-off and keeps it across online changes', async () => {
    const user = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Toggle Test' } });
    const repo = new PrismaDriverPresenceRepository(db);
    expect(await repo.upsert(user.id, { online: true })).toMatchObject({ rideEnabled: true, foodEnabled: true });
    expect(await repo.upsert(user.id, { online: true, foodEnabled: false })).toMatchObject({
      rideEnabled: true,
      foodEnabled: false,
    });
    expect(await repo.upsert(user.id, { online: false })).toMatchObject({ online: false, foodEnabled: false });
    expect(await repo.findByUserId(user.id)).toMatchObject({ foodEnabled: false, rideEnabled: true });
  });
});
