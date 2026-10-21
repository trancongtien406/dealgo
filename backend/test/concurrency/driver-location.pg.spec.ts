/** DEC-PROD-031: location heartbeat persists on driver_presence (Postgres). Skips without DATABASE_URL. */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaDriverPresenceRepository } from '../../src/modules/identity/driver-presence-prisma.repository.js';
import { uniqueTestPhone } from './test-phone.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('driver location heartbeat (postgres)', () => {
  let db: PrismaClient;

  beforeAll(() => {
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });
  });

  afterAll(async () => {
    await db?.$disconnect();
  });

  it('stores lat/lng/locationAt without touching online or service toggles', async () => {
    const user = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Location Test' } });
    const repo = new PrismaDriverPresenceRepository(db);
    await repo.upsert(user.id, { online: false, foodEnabled: false });
    expect((await repo.findByUserId(user.id))?.locationAt).toBeNull();

    const at = new Date('2026-10-20T03:00:00.000Z');
    const view = await repo.updateLocation(user.id, { lat: 16.06, lng: 108.21, at });
    expect(view).toMatchObject({ online: false, foodEnabled: false, rideEnabled: true, lat: 16.06, lng: 108.21 });
    expect(view.locationAt?.toISOString()).toBe(at.toISOString());

    // A later presence toggle without coordinates keeps the reported time.
    const toggled = await repo.upsert(user.id, { online: true });
    expect(toggled.locationAt?.toISOString()).toBe(at.toISOString());
  });

  it('creates an online row for a driver that never toggled presence', async () => {
    const user = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Location New' } });
    const repo = new PrismaDriverPresenceRepository(db);
    const view = await repo.updateLocation(user.id, { lat: 16.07, lng: 108.22, at: new Date() });
    expect(view).toMatchObject({ online: true, lat: 16.07, lng: 108.22 });
  });
});
