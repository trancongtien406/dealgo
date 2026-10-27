/**
 * DEC-PROD-017: concurrent wrong pickup-code guesses can never exceed the attempt limit, and two
 * first reads issue one code. Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaRidePickupCodeStore } from '../../src/modules/ride/ride-pickup-code.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ride pickup code (postgres)', () => {
  let prisma: PrismaService;
  let store: PrismaRidePickupCodeStore;
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
    store = new PrismaRidePickupCodeStore(db);
  });

  afterAll(async () => {
    await close();
  });

  async function insertRide(): Promise<string> {
    const db = prisma.db()!;
    const user = await db.user.create({ data: { displayName: 'pickup-code-pg' } });
    const ride = await db.ride.create({
      data: {
        vehicleClassCode: 'MOTORBIKE',
        customerId: user.id,
        pickupLat: 16.05,
        pickupLng: 108.2,
        pickupLabel: 'A',
        dropoffLat: 16.06,
        dropoffLng: 108.21,
        dropoffLabel: 'B',
        offeredFareVnd: 30_000,
        referenceFareVnd: 30_000,
        status: 'DRIVER_ARRIVED',
        expiresAt: new Date(Date.now() + 60_000),
        idempotencyKey: randomUUID(),
      },
    });
    return ride.id;
  }

  it('issues exactly one code when first reads race', async () => {
    const rideId = await insertRide();
    const results = await Promise.all(
      ['1111', '2222', '3333', '4444'].map((code) => store.ensure(rideId, code)),
    );
    expect(new Set(results.map((row) => row.code)).size).toBe(1);
  });

  it('never grants more than max attempts under concurrency', async () => {
    const rideId = await insertRide();
    await store.ensure(rideId, '5678');
    const granted = await Promise.all(Array.from({ length: 12 }, () => store.reserveAttempt(rideId, 5)));
    expect(granted.filter(Boolean)).toHaveLength(5);
    expect(await store.reserveAttempt(rideId, 5)).toBe(false);
  });
});
