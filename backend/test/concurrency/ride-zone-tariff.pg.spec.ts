/**
 * Owner t50u — per-zone tariff rows (versioned, audited in the same transaction) and the
 * write-once pricing snapshot on a ride. Skips without DATABASE_URL.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaRideZoneTariffRepository } from '../../src/modules/ride-vehicle/ride-zone-tariff.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ride zone tariff + pricing snapshot (postgres)', () => {
  let prisma: PrismaService;
  let close: () => Promise<void>;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              DATABASE_URL: process.env.DATABASE_URL,
              JWT_ACCESS_SECRET: 'test-access-secret',
            }),
        }),
        PrismaModule,
      ],
    }).compile();
    const app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    close = () => app.close();
  });

  const region = `T${randomUUID().slice(0, 6).toUpperCase()}`;
  const rideId = randomUUID();
  let actorId = '';

  afterAll(async () => {
    const db = prisma.db()!;
    const rows = await db.rideZoneTariff.findMany({ where: { regionCode: region } });
    await db.opsAuditLog.deleteMany({ where: { entityId: { in: rows.map((r) => r.id) } } });
    await db.opsAuditLog.deleteMany({ where: { actorUserId: actorId } });
    await db.rideZoneTariff.deleteMany({ where: { regionCode: region } });
    await db.ridePricingSnapshot.deleteMany({ where: { rideId } });
    if (actorId) await db.user.delete({ where: { id: actorId } });
    await close();
  });

  it('upsert bumps version with an audit row per edit; delete is audited too', async () => {
    const db = prisma.db()!;
    actorId = (await db.user.create({ data: { displayName: 'Zone Tariff Ops' } })).id;
    const repo = new PrismaRideZoneTariffRepository(db);
    const audit = (to: number) => ({ action: 'RIDE_ZONE_TARIFF_UPSERT' as const, reason: 'pg test', changes: { perKmVnd: { from: null, to } } });
    const first = await repo.upsert({ regionCode: region, vehicleClassCode: 'MOTORBIKE', perKmVnd: 6000, minFareVnd: 11_000 }, actorId, audit(6000));
    const second = await repo.upsert({ regionCode: region, vehicleClassCode: 'MOTORBIKE', perKmVnd: 6500, minFareVnd: 11_000 }, actorId, audit(6500));
    expect(second.id).toBe(first.id);
    expect(second.version).toBe(2);
    expect((await repo.list()).filter((r) => r.regionCode === region)).toHaveLength(1);
    expect(await db.opsAuditLog.count({ where: { entityId: first.id, action: 'RIDE_ZONE_TARIFF_UPSERT' } })).toBe(2);
    expect(await repo.remove(region, 'MOTORBIKE', actorId, { action: 'RIDE_ZONE_TARIFF_DELETE', reason: 'pg', changes: {} })).toBe(true);
    expect(await repo.remove(region, 'MOTORBIKE', actorId, { action: 'RIDE_ZONE_TARIFF_DELETE', reason: 'pg', changes: {} })).toBe(false);
    expect(await db.opsAuditLog.count({ where: { entityId: first.id, action: 'RIDE_ZONE_TARIFF_DELETE' } })).toBe(1);
  });

  it('pricing snapshot is write-once', async () => {
    const repo = new PrismaRideZoneTariffRepository(prisma.db()!);
    const snap = { rideId, regionCode: region, tariffSource: 'DEFAULT' as const, zoneTariffId: null, tariffVersion: 0, perKmVnd: 5000, minFareVnd: 10_000, bidFloorPercent: 70, bidCeilingPercent: 130 };
    await repo.saveSnapshot(snap);
    await repo.saveSnapshot({ ...snap, bidCeilingPercent: 200, perKmVnd: 9000 });
    expect(await repo.findSnapshot(rideId)).toMatchObject({ bidCeilingPercent: 130, perKmVnd: 5000 });
  });
});
