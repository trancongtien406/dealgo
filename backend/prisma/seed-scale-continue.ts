/**
 * Resume PERF_PROFILE=extreme seed from the highest existing perf:ride:N / perf:food:N.
 * Usage: npx tsx prisma/seed-scale-continue.ts
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { ensureFoodOrderLines } from './seed-food-order-lines.js';
import { ensureNegotiatingRides } from './seed-heal-negotiations.js';

function loadDotEnv(): void {
  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) return;
  for (const raw of readFileSync(envFile, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const eq = line.indexOf('=');
    const key = line.slice(0, eq).trim();
    if (process.env[key] !== undefined) continue;
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

const TARGET = Number(process.env.PERF_RIDES ?? process.env.PERF_ORDERS ?? 1_000_000);
const BATCH = Number(process.env.PERF_BATCH ?? 20_000);

async function main(): Promise<void> {
  loadDotEnv();
  const db = new PrismaClient({
    adapter: new PrismaPg({
      connectionString:
        process.env.DATABASE_URL?.trim() ||
        'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public',
    }),
  });

  process.on('exit', (code) => console.log(JSON.stringify({ msg: 'exit', code })));
  process.on('SIGTERM', () => console.log('SIGTERM'));
  process.on('SIGINT', () => console.log('SIGINT'));

  try {
    await db.$executeRawUnsafe(`SET statement_timeout = 0`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_customers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_drivers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_stores`);
    await db.$executeRawUnsafe(`
      CREATE UNLOGGED TABLE perf_seed_customers AS
      SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
      FROM users u
      JOIN role_grants rg ON rg."userId" = u.id AND rg.role = 'CUSTOMER' AND rg.status = 'ACTIVE'
      WHERE u.phone LIKE '+8499%'
    `);
    await db.$executeRawUnsafe(`CREATE INDEX ON perf_seed_customers (rn)`);
    await db.$executeRawUnsafe(`
      CREATE UNLOGGED TABLE perf_seed_drivers AS
      SELECT "userId" AS id, row_number() OVER (ORDER BY "userId") AS rn
      FROM role_grants WHERE role = 'DRIVER' AND status = 'ACTIVE'
    `);
    await db.$executeRawUnsafe(`CREATE INDEX ON perf_seed_drivers (rn)`);
    await db.$executeRawUnsafe(`
      CREATE UNLOGGED TABLE perf_seed_stores AS
      SELECT id, row_number() OVER (ORDER BY name) AS rn
      FROM food_stores WHERE name LIKE 'Perf Store %'
    `);
    await db.$executeRawUnsafe(`CREATE INDEX ON perf_seed_stores (rn)`);

    const counts = await db.$queryRawUnsafe<
      Array<{ cust: number; drivers: number; stores: number }>
    >(`
      SELECT
        (SELECT count(*)::int FROM perf_seed_customers) AS cust,
        (SELECT count(*)::int FROM perf_seed_drivers) AS drivers,
        (SELECT count(*)::int FROM perf_seed_stores) AS stores
    `);
    const custCount = Math.max(1, counts[0]?.cust ?? 1);
    const driverCount = Math.max(1, counts[0]?.drivers ?? 1);
    const storeCount = Math.max(1, counts[0]?.stores ?? 1);

    const maxRideRows = await db.$queryRawUnsafe<Array<{ m: number }>>(`
      SELECT COALESCE(max(substring("idempotencyKey" from 'perf:ride:([0-9]+)')::int), 0)::int AS m
      FROM rides
      WHERE "idempotencyKey" ~ '^perf:ride:[0-9]+$'
    `);
    let rideFrom = (maxRideRows[0]?.m ?? 0) + 1;
    console.log(JSON.stringify({ msg: 'continue.rides', from: rideFrom, target: TARGET }));

    for (let offset = rideFrom - 1; offset < TARGET; offset += BATCH) {
      const from = offset + 1;
      const to = Math.min(offset + BATCH, TARGET);
      await db.$executeRawUnsafe(`
        INSERT INTO rides (
          id, "customerId", "pickupLat", "pickupLng", "pickupLabel",
          "dropoffLat", "dropoffLng", "dropoffLabel",
          "offeredFareVnd", "referenceFareVnd", "agreedFareVnd",
          status, "assignedDriverId", "expiresAt", "idempotencyKey",
          "createdAt", "updatedAt"
        )
        SELECT
          gen_random_uuid(), c.id,
          10.77 + ((s.seq % 50) - 25) * 0.001,
          106.70 + ((s.seq % 50) - 25) * 0.001,
          'Perf pickup ' || s.seq,
          10.78 + ((s.seq % 50) - 25) * 0.001,
          106.71 + ((s.seq % 50) - 25) * 0.001,
          'Perf dropoff ' || s.seq,
          25000, 28000, 26000,
          ((ARRAY['COMPLETED','CANCELLED','EXPIRED'])[1 + (s.seq % 3)])::"RideStatus",
          CASE WHEN s.seq % 2 = 0 THEN d.id ELSE NULL END,
          now() + interval '1 hour',
          'perf:ride:' || s.seq,
          now(), now()
        FROM generate_series(${from}, ${to}) AS s(seq)
        JOIN perf_seed_customers c ON c.rn = 1 + ((s.seq - 1) % ${custCount})
        LEFT JOIN perf_seed_drivers d ON d.rn = 1 + ((s.seq - 1) % ${driverCount})
        ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
      `);
      console.log(JSON.stringify({ msg: 'rides', to, target: TARGET }));
    }

    const maxFoodRows = await db.$queryRawUnsafe<Array<{ m: number }>>(`
      SELECT COALESCE(max(substring("idempotencyKey" from 'perf:food:([0-9]+)')::int), 0)::int AS m
      FROM food_orders
      WHERE "idempotencyKey" ~ '^perf:food:[0-9]+$'
    `);
    let foodFrom = (maxFoodRows[0]?.m ?? 0) + 1;
    console.log(JSON.stringify({ msg: 'continue.orders', from: foodFrom, target: TARGET }));

    for (let offset = foodFrom - 1; offset < TARGET; offset += BATCH) {
      const from = offset + 1;
      const to = Math.min(offset + BATCH, TARGET);
      await db.$executeRawUnsafe(`
        INSERT INTO food_orders (
          id, "customerId", "storeId", status,
          "deliveryFareVnd", "subtotalVnd", "totalVnd",
          "dropoffLat", "dropoffLng", "dropoffLabel",
          "assignedDriverId", "idempotencyKey",
          "createdAt", "updatedAt"
        )
        SELECT
          gen_random_uuid(), c.id, st.id,
          ((ARRAY['DELIVERED','CANCELLED','FAILED'])[1 + (s.seq % 3)])::"FoodOrderStatus",
          15000, 50000, 65000,
          10.77, 106.70, 'Perf dropoff ' || s.seq,
          CASE WHEN s.seq % 3 = 0 THEN d.id ELSE NULL END,
          'perf:food:' || s.seq,
          now(), now()
        FROM generate_series(${from}, ${to}) AS s(seq)
        JOIN perf_seed_customers c ON c.rn = 1 + ((s.seq - 1) % ${custCount})
        JOIN perf_seed_stores st ON st.rn = 1 + ((s.seq - 1) % ${storeCount})
        LEFT JOIN perf_seed_drivers d ON d.rn = 1 + ((s.seq - 1) % ${driverCount})
        ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
      `);
      console.log(JSON.stringify({ msg: 'orders', to, target: TARGET }));
    }

    const lineHeal = await ensureFoodOrderLines(db);
    console.log(JSON.stringify({ msg: 'seed-continue.food-order-lines', ...lineHeal }));
    if (lineHeal.ordersStillMissingLines > 0) {
      throw new Error(
        `food_order_lines heal left ${lineHeal.ordersStillMissingLines} orders without lines`,
      );
    }

    const negoHeal = await ensureNegotiatingRides(db);
    console.log(JSON.stringify({ msg: 'seed-continue.heal-negotiations', ...negoHeal }));

    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_customers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_drivers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_stores`);
    console.log(JSON.stringify({ msg: 'seed-continue.done', target: TARGET }));
  } finally {
    await db.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
