/** DEC-PROD-071: parcel row is atomic with its ride; code attempts are capped under races. Skips without DATABASE_URL. */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaRideRepository } from '../../src/modules/ride/ride-prisma.repository.js';
import { PrismaRideParcelStore, type NewParcel } from '../../src/modules/ride/ride-parcel.store.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ride parcel (postgres)', () => {
  let prisma: PrismaService;
  let rides: PrismaRideRepository;
  let store: PrismaRideParcelStore;
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
    store = new PrismaRideParcelStore(db);
  });

  afterAll(async () => {
    await close();
  });

  async function input() {
    const user = await prisma.db()!.user.create({ data: { displayName: 'parcel-pg' } });
    const now = new Date();
    return {
      customerId: user.id, idempotencyKey: randomUUID(),
      pickup: { lat: 16.05, lng: 108.2, label: 'A' }, dropoff: { lat: 16.06, lng: 108.21, label: 'B' },
      offeredFareVnd: 30_000, referenceFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE',
      expiresAt: new Date(now.getTime() + 60_000), now,
    };
  }
  const parcel = (rideId: string): NewParcel => ({
    rideId, senderName: 'A', senderPhone: '0901234567', recipientName: 'B',
    recipientPhone: '0907654321', sizeClass: 'S', weightKg: 1, note: null, payer: 'SENDER',
    surchargeVnd: 0, serviceFeeVnd: 0, returnFeeVnd: 0, itemPhoto: null, recipientCode: '1234',
  });

  it('rolls back the ride when the parcel step fails inside the transaction', async () => {
    const dto = await input();
    let seen = '';
    await expect(
      rides.create(dto, async ({ tx, rideId }) => {
        seen = rideId;
        await store.create(parcel(rideId), tx);
        throw new Error('boom');
      }),
    ).rejects.toThrow('boom');
    const db = prisma.db()!;
    expect(await db.ride.findUnique({ where: { id: seen } })).toBeNull();
    expect(await db.rideParcel.findUnique({ where: { rideId: seen } })).toBeNull();
  });

  it('commits ride and parcel together; replay keeps one row', async () => {
    const dto = await input();
    const hook = async ({ tx, rideId }: { tx: unknown; rideId: string }) => {
      await store.create(parcel(rideId), tx);
    };
    const [a, b] = await Promise.all([rides.create(dto, hook), rides.create(dto, hook)]);
    expect(b.id).toBe(a.id);
    expect(await prisma.db()!.rideParcel.count({ where: { rideId: a.id } })).toBe(1);
  });

  it('concurrent recipient-code attempts never exceed the cap', async () => {
    const ride = await rides.create(await input(), async ({ tx, rideId }) => {
      await store.create(parcel(rideId), tx);
    });
    const results = await Promise.all(Array.from({ length: 8 }, () => store.reserveCodeAttempt(ride.id, 3)));
    expect(results.filter(Boolean)).toHaveLength(3);
  });
});
