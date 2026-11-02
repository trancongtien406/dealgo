/**
 * DEC-PROD-034 — lifetime driver job counts (rides + food) via Postgres groupBy, and the store
 * pickup point snapshotted on the food order at placement. Skips without DATABASE_URL.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';
import { PrismaRideRepository } from '../../src/modules/ride/ride-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('driver stats + pickup snapshot (postgres)', () => {
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

  afterAll(async () => {
    await close();
  });

  it('keeps the placement pickup point and counts finished jobs per assigned driver', async () => {
    const db = prisma.db()!;
    const food = new PrismaFoodRepository(db as never);
    const rides = new PrismaRideRepository(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Stats Owner' } });
    const customer = await db.user.create({ data: { displayName: 'Stats Customer', phone: `+8491${tag}` } });
    const driver = await db.user.create({ data: { displayName: 'Stats Driver' } });
    const idle = await db.user.create({ data: { displayName: 'Idle Driver' } });
    const store = await db.foodStore.create({
      data: {
        ownerId: owner.id,
        name: `Stats ${tag}`,
        lat: 16.0611,
        lng: 108.2233,
        addressLabel: '12 Bạch Đằng',
      },
    });
    const item = await food.createItem({ ownerId: owner.id, name: 'Mì Quảng', priceVnd: 40_000 });
    await db.foodItem.update({ where: { id: item.id }, data: { moderationStatus: 'APPROVED' } }); // FOOD-001

    const place = (key: string) =>
      food.place({
        customerId: customer.id,
        storeId: store.id,
        idempotencyKey: `idem-stats-${key}-${tag}`,
        items: [{ itemId: item.id, quantity: 1 }],
        dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
        deliveryFareVnd: 15_000,
      });
    const first = await place('a');
    expect(first.pickup).toEqual({ lat: 16.0611, lng: 108.2233, label: '12 Bạch Đằng' });

    // Store moves after placement: the order keeps the snapshot.
    await db.foodStore.update({ where: { id: store.id }, data: { lat: 16.1, lng: 108.3, addressLabel: 'Mới' } });
    expect((await food.findOrder(first.id))?.pickup).toEqual({
      lat: 16.0611,
      lng: 108.2233,
      label: '12 Bạch Đằng',
    });

    await db.foodOrder.update({
      where: { id: first.id },
      data: { status: 'DELIVERED', assignedDriverId: driver.id },
    });
    const second = await place('b');
    await db.foodOrder.update({
      where: { id: second.id },
      data: { status: 'FAILED', assignedDriverId: driver.id },
    });

    // DEC-PROD-035: only DRIVER cancellations count against the driver.
    const third = await place('c');
    await db.foodOrder.update({
      where: { id: third.id },
      data: { status: 'CANCELLED', cancelledBy: 'OPS', assignedDriverId: driver.id },
    });

    const ride = (
      status: 'COMPLETED' | 'CANCELLED' | 'IN_TRIP',
      cancelledBy: 'DRIVER' | 'CUSTOMER' | null = null,
    ) =>
      db.ride.create({
        data: {
          vehicleClassCode: 'MOTORBIKE',
          id: randomUUID(),
          customerId: customer.id,
          pickupLat: 16.05,
          pickupLng: 108.2,
          pickupLabel: 'A',
          dropoffLat: 16.06,
          dropoffLng: 108.21,
          dropoffLabel: 'B',
          offeredFareVnd: 30_000,
          referenceFareVnd: 30_000,
          agreedFareVnd: 30_000,
          status,
          cancelledBy,
          assignedDriverId: driver.id,
          expiresAt: new Date(Date.now() + 600_000),
          idempotencyKey: `idem-stats-ride-${status}-${cancelledBy ?? 'none'}-${tag}`,
        },
      });
    await ride('COMPLETED');
    await ride('CANCELLED', 'DRIVER');
    await ride('CANCELLED', 'CUSTOMER');
    await ride('IN_TRIP');

    const rideCounts = await rides.countFinishedForDrivers([driver.id, idle.id]);
    const foodCounts = await food.countFinishedForDrivers([driver.id, idle.id]);
    expect(rideCounts.get(driver.id)).toEqual({ completed: 1, finished: 2 });
    expect(foodCounts.get(driver.id)).toEqual({ completed: 1, finished: 2 });
    expect(rideCounts.has(idle.id)).toBe(false);
    expect(foodCounts.has(idle.id)).toBe(false);
    expect((await rides.countFinishedForDrivers([])).size).toBe(0);

    // The Prisma repository persists the actor on a real customer cancel.
    const open = await db.ride.create({
      data: {
        vehicleClassCode: 'MOTORBIKE',
        id: randomUUID(),
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
        expiresAt: new Date(Date.now() + 600_000),
        idempotencyKey: `idem-stats-ride-open-${tag}`,
      },
    });
    const cancelled = await rides.cancel({ rideId: open.id, customerId: customer.id, now: new Date() });
    expect(cancelled.cancelledBy).toBe('CUSTOMER');
    expect((await db.ride.findUniqueOrThrow({ where: { id: open.id } })).cancelledBy).toBe('CUSTOMER');
  });
});
