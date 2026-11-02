/**
 * RIDE-003: two customers select the same driver at the same time. The driver lock lets exactly
 * one win; the winner's PENDING offer on the other ride is WITHDRAWN in the same transaction and
 * the loser gets a rule error instead of a second assignment. Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaRideRepository } from '../../src/modules/ride/ride-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ride select withdraws the winner\'s other offers (postgres)', () => {
  let prisma: PrismaService;
  let rides: PrismaRideRepository;
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
    close = () => app.close();
    prisma = app.get(PrismaService);
    const db = prisma.db();
    if (!db) {
      throw new Error('prisma client missing');
    }
    rides = new PrismaRideRepository(db);
  });

  afterAll(async () => {
    await close();
  });

  async function negotiatingRideWithOffer(driverId: string) {
    const db = prisma.db()!;
    const customer = await db.user.create({ data: { displayName: 'ride-003-customer' } });
    const ride = await db.ride.create({
      data: {
        vehicleClassCode: 'MOTORBIKE',
        customerId: customer.id,
        pickupLat: 16.05,
        pickupLng: 108.2,
        pickupLabel: 'A',
        dropoffLat: 16.06,
        dropoffLng: 108.21,
        dropoffLabel: 'B',
        offeredFareVnd: 30_000,
        referenceFareVnd: 30_000,
        status: 'NEGOTIATING',
        expiresAt: new Date(Date.now() + 300_000),
        idempotencyKey: randomUUID(),
      },
    });
    const offer = await db.rideOffer.create({
      data: {
        rideId: ride.id,
        driverId,
        amountVnd: 30_000,
        kind: 'ACCEPT',
        status: 'PENDING',
        expiresAt: new Date(Date.now() + 60_000),
      },
    });
    return { customerId: customer.id, rideId: ride.id, offerId: offer.id };
  }

  it('assigns the driver once and withdraws the losing ride\'s offer', async () => {
    const db = prisma.db()!;
    const driver = await db.user.create({ data: { displayName: 'ride-003-driver' } });
    const a = await negotiatingRideWithOffer(driver.id);
    const b = await negotiatingRideWithOffer(driver.id);
    const notified: string[][] = [];
    const now = new Date();

    const results = await Promise.allSettled(
      [a, b].map((r) =>
        rides.select({
          rideId: r.rideId,
          customerId: r.customerId,
          offerId: r.offerId,
          idempotencyKey: randomUUID(),
          now,
          maxConcurrentJobs: 1,
          onOffersWithdrawn: (ids) => notified.push(ids),
        }),
      ),
    );

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((r) => r.status === 'rejected')).toHaveLength(1);
    const assigned = await db.ride.count({
      where: { id: { in: [a.rideId, b.rideId] }, assignedDriverId: driver.id },
    });
    expect(assigned).toBe(1);
    const offers = await db.rideOffer.findMany({
      where: { id: { in: [a.offerId, b.offerId] } },
      select: { status: true },
    });
    expect(offers.map((o) => o.status).sort()).toEqual(['SELECTED', 'WITHDRAWN'].sort());
    expect(notified).toHaveLength(1);
  });
});
