/**
 * Bulk scale seed for performance testing.
 *
 * Profiles (PERF_PROFILE):
 *   smoke   — ~10k rides + ~10k food orders (default for quick matrix)
 *   load    — ~100k each
 *   extreme — ~1M each (disk/time heavy; run overnight-capable)
 *
 * Overrides:
 *   PERF_RIDES / PERF_ORDERS / PERF_STORES / PERF_USERS / PERF_BATCH
 *
 * Usage:
 *   PERF_PROFILE=smoke npm run seed:scale
 *   PERF_PROFILE=extreme npm run seed:scale
 *
 * Safe to re-run: uses dedicated phone/email prefixes and idempotency keys
 * under `perf:*` so demo seed rows are not rewritten.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { ensureFoodOrderLines } from './seed-food-order-lines.js';
import { ensureNegotiatingRides } from './seed-heal-negotiations.js';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';

type Profile = {
  users: number;
  stores: number;
  rides: number;
  orders: number;
  messagesPerThread: number;
  batch: number;
};

const PROFILES: Record<string, Profile> = {
  smoke: { users: 2_000, stores: 200, rides: 10_000, orders: 10_000, messagesPerThread: 2, batch: 2_000 },
  load: { users: 20_000, stores: 2_000, rides: 100_000, orders: 100_000, messagesPerThread: 3, batch: 5_000 },
  extreme: {
    users: 100_000,
    stores: 10_000,
    rides: 1_000_000,
    orders: 1_000_000,
    messagesPerThread: 2,
    batch: 10_000,
  },
};

const CATEGORIES = ['cafe', 'pho', 'rice', 'noodles', 'seafood', 'bakery'] as const;
const HCM = { lat: 10.7769, lng: 106.7009 };
const DNG = { lat: 16.0544, lng: 108.2022 };

function loadDotEnv(): void {
  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) {
    return;
  }
  for (const raw of readFileSync(envFile, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) {
      continue;
    }
    const eq = line.indexOf('=');
    const key = line.slice(0, eq).trim();
    if (process.env[key] !== undefined) {
      continue;
    }
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

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
}

function resolveProfile(): Profile & { name: string } {
  const name = (process.env.PERF_PROFILE?.trim() || 'smoke').toLowerCase();
  const base = PROFILES[name] ?? PROFILES.smoke;
  return {
    name: PROFILES[name] ? name : 'smoke',
    users: intEnv('PERF_USERS', base.users),
    stores: intEnv('PERF_STORES', base.stores),
    rides: intEnv('PERF_RIDES', base.rides),
    orders: intEnv('PERF_ORDERS', base.orders),
    messagesPerThread: intEnv('PERF_CHAT_MSGS', base.messagesPerThread),
    batch: intEnv('PERF_BATCH', base.batch),
  };
}

function jitter(base: number, spread: number, i: number): number {
  const wave = ((i % 97) - 48) / 48;
  return base + wave * spread;
}

async function main(): Promise<void> {
  loadDotEnv();
  const profile = resolveProfile();
  const databaseUrl = process.env.DATABASE_URL?.trim() || LOCAL_DATABASE_URL;
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: databaseUrl }) });
  const started = Date.now();

  console.log(
    JSON.stringify({
      msg: 'seed-scale.start',
      profile: profile.name,
      targets: profile,
      database: databaseUrl.replace(/:[^:@/]+@/, ':***@'),
    }),
  );

  try {
    await db.$executeRawUnsafe(`CREATE EXTENSION IF NOT EXISTS pgcrypto`);

    // --- Users (customers + drivers + merchants interleaved) ---
    for (let offset = 0; offset < profile.users; offset += profile.batch) {
      const n = Math.min(profile.batch, profile.users - offset);
      await db.$executeRawUnsafe(
        `
        INSERT INTO users (id, phone, email, "displayName", "phoneVerifiedAt", "createdAt", "updatedAt")
        SELECT
          gen_random_uuid(),
          '+8499' || lpad((${offset} + g)::text, 7, '0'),
          'perf.user.' || (${offset} + g)::text || '@example.invalid',
          'Perf User ' || (${offset} + g)::text,
          now(),
          now(),
          now()
        FROM generate_series(1, ${n}) AS g
        ON CONFLICT (phone) DO NOTHING
        `,
      );
      process.stdout.write(`users ${Math.min(offset + n, profile.users)}/${profile.users}\r`);
    }
    console.log(`\nusers done`);

    await db.$executeRawUnsafe(
      `
      INSERT INTO role_grants (id, "userId", role, status, "createdAt")
      SELECT gen_random_uuid(), u.id, 'CUSTOMER', 'ACTIVE', now()
      FROM users u
      WHERE u.phone LIKE '+8499%'
        AND NOT EXISTS (
          SELECT 1 FROM role_grants rg WHERE rg."userId" = u.id AND rg.role = 'CUSTOMER'
        )
      `,
    );

    // Every 5th user → DRIVER, every 7th → MERCHANT
    await db.$executeRawUnsafe(
      `
      INSERT INTO role_grants (id, "userId", role, status, "createdAt")
      SELECT gen_random_uuid(), u.id, 'DRIVER', 'ACTIVE', now()
      FROM (
        SELECT id, row_number() OVER (ORDER BY phone) AS rn
        FROM users WHERE phone LIKE '+8499%'
      ) u
      WHERE u.rn % 5 = 0
        AND NOT EXISTS (
          SELECT 1 FROM role_grants rg WHERE rg."userId" = u.id AND rg.role = 'DRIVER'
        )
      `,
    );
    await db.$executeRawUnsafe(
      `
      INSERT INTO role_grants (id, "userId", role, status, "createdAt")
      SELECT gen_random_uuid(), u.id, 'MERCHANT', 'ACTIVE', now()
      FROM (
        SELECT id, row_number() OVER (ORDER BY phone) AS rn
        FROM users WHERE phone LIKE '+8499%'
      ) u
      WHERE u.rn % 7 = 0
        AND NOT EXISTS (
          SELECT 1 FROM role_grants rg WHERE rg."userId" = u.id AND rg.role = 'MERCHANT'
        )
      `,
    );

    await db.$executeRawUnsafe(
      `
      INSERT INTO driver_presence ("userId", online, lat, lng, "updatedAt")
      SELECT u.id, (u.rn % 3 <> 0),
        ${HCM.lat} + ((u.rn % 50) - 25) * 0.002,
        ${HCM.lng} + ((u.rn % 40) - 20) * 0.002,
        now()
      FROM (
        SELECT rg."userId" AS id, row_number() OVER (ORDER BY rg."userId") AS rn
        FROM role_grants rg WHERE rg.role = 'DRIVER' AND rg.status = 'ACTIVE'
      ) u
      ON CONFLICT ("userId") DO UPDATE SET
        online = EXCLUDED.online,
        lat = EXCLUDED.lat,
        lng = EXCLUDED.lng,
        "updatedAt" = now()
      `,
    );

    // --- Stores ---
    const merchantCount = await db.$queryRawUnsafe<Array<{ c: bigint }>>(
      `SELECT count(*)::bigint AS c FROM role_grants WHERE role = 'MERCHANT' AND status = 'ACTIVE'`,
    );
    const merchants = Number(merchantCount[0]?.c ?? 0n);
    if (merchants === 0) {
      throw new Error('No merchant grants available for store seed');
    }
    const storesTarget = Math.min(profile.stores, merchants);
    await db.$executeRawUnsafe(
      `
      INSERT INTO food_stores (id, "ownerId", name, category, lat, lng, "createdAt")
      SELECT
        gen_random_uuid(),
        m.id,
        'Perf Store ' || m.rn::text,
        (ARRAY[${CATEGORIES.map((c) => `'${c}'`).join(',')}])[1 + (m.rn % ${CATEGORIES.length})],
        CASE WHEN m.rn % 2 = 0 THEN ${HCM.lat} ELSE ${DNG.lat} END
          + ((m.rn % 60) - 30) * 0.0015,
        CASE WHEN m.rn % 2 = 0 THEN ${HCM.lng} ELSE ${DNG.lng} END
          + ((m.rn % 60) - 30) * 0.0015,
        now()
      FROM (
        SELECT rg."userId" AS id, row_number() OVER (ORDER BY rg."userId") AS rn
        FROM role_grants rg WHERE rg.role = 'MERCHANT' AND rg.status = 'ACTIVE'
      ) m
      WHERE m.rn <= ${storesTarget}
        AND NOT EXISTS (
          SELECT 1 FROM food_stores fs WHERE fs."ownerId" = m.id AND fs.name = 'Perf Store ' || m.rn::text
        )
      `,
    );

    await db.$executeRawUnsafe(
      `
      INSERT INTO food_items (id, "storeId", name, "priceVnd", available)
      SELECT gen_random_uuid(), s.id, item.name, item.price, true
      FROM food_stores s
      CROSS JOIN (VALUES
        ('Combo A', 45000),
        ('Combo B', 65000),
        ('Drink', 25000)
      ) AS item(name, price)
      WHERE s.name LIKE 'Perf Store %'
        AND NOT EXISTS (
          SELECT 1 FROM food_items fi WHERE fi."storeId" = s.id AND fi.name = item.name
        )
      `,
    );
    console.log(`stores/items done (target=${storesTarget})`);

    // Staging lookup tables (pool-safe; TEMP tables do not survive across Prisma queries).
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_customers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_drivers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_stores`);
    await db.$executeRawUnsafe(
      `
      CREATE UNLOGGED TABLE perf_seed_customers AS
      SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
      FROM users u
      JOIN role_grants rg ON rg."userId" = u.id AND rg.role = 'CUSTOMER' AND rg.status = 'ACTIVE'
      WHERE u.phone LIKE '+8499%'
      `,
    );
    await db.$executeRawUnsafe(
      `CREATE INDEX perf_seed_customers_rn ON perf_seed_customers (rn)`,
    );
    await db.$executeRawUnsafe(
      `
      CREATE UNLOGGED TABLE perf_seed_drivers AS
      SELECT rg."userId" AS id, row_number() OVER (ORDER BY rg."userId") AS rn
      FROM role_grants rg WHERE rg.role = 'DRIVER' AND rg.status = 'ACTIVE'
      `,
    );
    await db.$executeRawUnsafe(`CREATE INDEX perf_seed_drivers_rn ON perf_seed_drivers (rn)`);
    await db.$executeRawUnsafe(
      `
      CREATE UNLOGGED TABLE perf_seed_stores AS
      SELECT id, row_number() OVER (ORDER BY name) AS rn
      FROM food_stores WHERE name LIKE 'Perf Store %'
      `,
    );
    await db.$executeRawUnsafe(`CREATE INDEX perf_seed_stores_rn ON perf_seed_stores (rn)`);

    const custCountRows = await db.$queryRawUnsafe<Array<{ c: bigint }>>(
      `SELECT count(*)::bigint AS c FROM perf_seed_customers`,
    );
    const driverCountRows = await db.$queryRawUnsafe<Array<{ c: bigint }>>(
      `SELECT count(*)::bigint AS c FROM perf_seed_drivers`,
    );
    const storeCountRows = await db.$queryRawUnsafe<Array<{ c: bigint }>>(
      `SELECT count(*)::bigint AS c FROM perf_seed_stores`,
    );
    const custCount = Math.max(1, Number(custCountRows[0]?.c ?? 1n));
    const driverCount = Math.max(1, Number(driverCountRows[0]?.c ?? 1n));
    const storeCount = Math.max(1, Number(storeCountRows[0]?.c ?? 1n));
    console.log(
      JSON.stringify({ msg: 'seed-scale.staging', custCount, driverCount, storeCount }),
    );

    await db.$executeRawUnsafe(`SET statement_timeout = 0`);

    // --- Rides ---
    for (let offset = 0; offset < profile.rides; offset += profile.batch) {
      const n = Math.min(profile.batch, profile.rides - offset);
      try {
        await db.$executeRawUnsafe(
          `
          INSERT INTO rides (
            id, "customerId", "pickupLat", "pickupLng", "pickupLabel",
            "dropoffLat", "dropoffLng", "dropoffLabel",
            "offeredFareVnd", "referenceFareVnd", "agreedFareVnd",
            status, "assignedDriverId", "expiresAt", "idempotencyKey",
            "createdAt", "updatedAt"
          )
          SELECT
            gen_random_uuid(),
            c.id,
            ${jitter(HCM.lat, 0.05, 0)} + ((s.seq % 80) - 40) * 0.0008,
            ${jitter(HCM.lng, 0.05, 1)} + ((s.seq % 70) - 35) * 0.0008,
            'Perf pickup ' || s.seq::text,
            ${jitter(HCM.lat, 0.05, 2)} + ((s.seq % 90) - 45) * 0.0008,
            ${jitter(HCM.lng, 0.05, 3)} + ((s.seq % 85) - 42) * 0.0008,
            'Perf dropoff ' || s.seq::text,
            20000 + (s.seq % 40) * 1000,
            25000 + (s.seq % 30) * 1000,
            CASE WHEN s.seq % 10 IN (0,1,2,3,4,5) THEN 22000 + (s.seq % 20) * 1000 ELSE NULL END,
            ((ARRAY['ASSIGNED','DRIVER_EN_ROUTE','IN_TRIP','COMPLETED','CANCELLED','EXPIRED'])[1 + (s.seq % 6)])::"RideStatus",
            CASE WHEN s.seq % 10 IN (0,1,2,3,4,5) THEN d.id ELSE NULL END,
            now() + ((s.seq % 120) || ' minutes')::interval,
            'perf:ride:' || s.seq::text,
            now() - ((s.seq % 10_000) || ' seconds')::interval,
            now() - ((s.seq % 10_000) || ' seconds')::interval
          FROM generate_series(${offset + 1}, ${offset + n}) AS s(seq)
          JOIN perf_seed_customers c ON c.rn = 1 + ((s.seq - 1) % ${custCount})
          LEFT JOIN perf_seed_drivers d ON d.rn = 1 + ((s.seq - 1) % ${driverCount})
          ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
          `,
        );
      } catch (error) {
        console.error(`rides batch failed at offset=${offset}`, error);
        throw error;
      }
      if ((offset / profile.batch) % 10 === 0 || offset + n >= profile.rides) {
        console.log(`rides ${Math.min(offset + n, profile.rides)}/${profile.rides}`);
      }
    }
    console.log(`rides done`);

    // --- Food orders ---
    for (let offset = 0; offset < profile.orders; offset += profile.batch) {
      const n = Math.min(profile.batch, profile.orders - offset);
      try {
        await db.$executeRawUnsafe(
          `
          INSERT INTO food_orders (
            id, "customerId", "storeId", status,
            "deliveryFareVnd", "subtotalVnd", "totalVnd",
            "dropoffLat", "dropoffLng", "dropoffLabel",
            "assignedDriverId", "idempotencyKey",
            "createdAt", "updatedAt"
          )
          SELECT
            gen_random_uuid(),
            c.id,
            st.id,
            ((ARRAY['DELIVERED','CANCELLED','FAILED'])[1 + (s.seq % 3)])::"FoodOrderStatus",
            15000 + (s.seq % 15) * 1000,
            50000 + (s.seq % 20) * 2000,
            65000 + (s.seq % 20) * 2000,
            ${HCM.lat} + ((s.seq % 50) - 25) * 0.001,
            ${HCM.lng} + ((s.seq % 50) - 25) * 0.001,
            'Perf dropoff ' || s.seq::text,
            CASE WHEN s.seq % 3 = 0 THEN d.id ELSE NULL END,
            'perf:food:' || s.seq::text,
            now() - ((s.seq % 20_000) || ' seconds')::interval,
            now() - ((s.seq % 20_000) || ' seconds')::interval
          FROM generate_series(${offset + 1}, ${offset + n}) AS s(seq)
          JOIN perf_seed_customers c ON c.rn = 1 + ((s.seq - 1) % ${custCount})
          JOIN perf_seed_stores st ON st.rn = 1 + ((s.seq - 1) % ${storeCount})
          LEFT JOIN perf_seed_drivers d ON d.rn = 1 + ((s.seq - 1) % ${driverCount})
          ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
          `,
        );
      } catch (error) {
        console.error(`orders batch failed at offset=${offset}`, error);
        throw error;
      }
      if ((offset / profile.batch) % 10 === 0 || offset + n >= profile.orders) {
        console.log(`orders ${Math.min(offset + n, profile.orders)}/${profile.orders}`);
      }
    }
    console.log(`orders done`);

    // Heal leftover open orders from interrupted scale runs (partial unique index).
    await db.$executeRawUnsafe(
      `
      UPDATE food_orders
      SET status = 'DELIVERED'::"FoodOrderStatus", "updatedAt" = now()
      WHERE "idempotencyKey" LIKE 'perf:food:%'
        AND "idempotencyKey" NOT LIKE 'perf:food:ready:%'
        AND status IN ('PLACED','PREPARING','READY','ASSIGNED','PICKED_UP')
      `,
    );

    // One open ride + one READY food order per eligible customer (dispatch hot paths)
    await db.$executeRawUnsafe(
      `
      WITH customers AS (
        SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
        FROM users u
        JOIN role_grants rg ON rg."userId" = u.id AND rg.role = 'CUSTOMER' AND rg.status = 'ACTIVE'
        WHERE u.phone LIKE '+8499%'
      )
      INSERT INTO rides (
        id, "customerId", "pickupLat", "pickupLng", "pickupLabel",
        "dropoffLat", "dropoffLng", "dropoffLabel",
        "offeredFareVnd", "referenceFareVnd", status, "expiresAt", "idempotencyKey",
        "createdAt", "updatedAt"
      )
      SELECT
        gen_random_uuid(), c.id,
        ${HCM.lat}, ${HCM.lng}, 'Perf open pickup',
        ${HCM.lat} + 0.01, ${HCM.lng} + 0.01, 'Perf open drop',
        30000, 32000, 'NEGOTIATING'::"RideStatus",
        now() + interval '30 minutes',
        'perf:ride:open:' || c.rn::text,
        now(), now()
      FROM customers c
      WHERE c.rn <= LEAST(500, (SELECT count(*) FROM customers))
        AND NOT EXISTS (
          SELECT 1 FROM rides r WHERE r."customerId" = c.id AND r.status = 'NEGOTIATING'
        )
      ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
      `,
    );

    await db.$executeRawUnsafe(
      `
      WITH customers AS (
        SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
        FROM users u
        JOIN role_grants rg ON rg."userId" = u.id AND rg.role = 'CUSTOMER' AND rg.status = 'ACTIVE'
        WHERE u.phone LIKE '+8499%'
      ),
      stores AS (
        SELECT id, row_number() OVER (ORDER BY name) AS rn
        FROM food_stores WHERE name LIKE 'Perf Store %'
      )
      INSERT INTO food_orders (
        id, "customerId", "storeId", status,
        "deliveryFareVnd", "subtotalVnd", "totalVnd",
        "dropoffLat", "dropoffLng", "dropoffLabel",
        "idempotencyKey", "createdAt", "updatedAt"
      )
      SELECT
        gen_random_uuid(), c.id, st.id, 'READY'::"FoodOrderStatus",
        12000, 55000, 67000,
        ${HCM.lat}, ${HCM.lng}, 'Perf ready drop',
        'perf:food:ready:' || c.rn::text,
        now(), now()
      FROM customers c
      JOIN stores st ON st.rn = 1 + ((c.rn - 1) % (SELECT count(*) FROM stores))
      WHERE c.rn <= LEAST(500, (SELECT count(*) FROM customers))
        AND NOT EXISTS (
          SELECT 1 FROM food_orders o
          WHERE o."customerId" = c.id
            AND o.status IN ('PLACED','PREPARING','READY','ASSIGNED')
        )
      ON CONFLICT ("customerId", "idempotencyKey") DO NOTHING
      `,
    );

    // Ensure catalog items on stores missing them, then ≥1 line per order (idempotent).
    const lineHeal = await ensureFoodOrderLines(db);
    console.log(JSON.stringify({ msg: 'seed-scale.food-order-lines', ...lineHeal }));
    if (lineHeal.ordersStillMissingLines > 0) {
      throw new Error(
        `food_order_lines heal left ${lineHeal.ordersStillMissingLines} orders without lines`,
      );
    }

    // Demo-sized open negotiations + offers (scale open rides expire quickly).
    const negoHeal = await ensureNegotiatingRides(db);
    console.log(JSON.stringify({ msg: 'seed-scale.heal-negotiations', ...negoHeal }));
    if (negoHeal.healNegotiating < 8) {
      throw new Error(
        `negotiations heal left only ${negoHeal.healNegotiating} heal NEGOTIATING rides (need ≥8)`,
      );
    }

    // Chat threads + messages for a subset of completed rides
    await db.$executeRawUnsafe(
      `
      INSERT INTO chat_threads (id, "rideId", "createdAt")
      SELECT gen_random_uuid(), r.id, r."createdAt"
      FROM rides r
      WHERE r."idempotencyKey" LIKE 'perf:ride:%'
        AND r.status IN ('ASSIGNED','IN_TRIP','COMPLETED')
        AND NOT EXISTS (SELECT 1 FROM chat_threads t WHERE t."rideId" = r.id)
      LIMIT ${Math.min(profile.rides, 50_000)}
      `,
    );

    if (profile.messagesPerThread > 0) {
      await db.$executeRawUnsafe(
        `
        INSERT INTO chat_messages (id, "threadId", "senderUserId", body, "createdAt")
        SELECT gen_random_uuid(), t.id, r."customerId",
          'Perf msg ' || g::text || ' for ' || r."idempotencyKey",
          r."createdAt" + (g || ' minutes')::interval
        FROM chat_threads t
        JOIN rides r ON r.id = t."rideId"
        CROSS JOIN generate_series(1, ${profile.messagesPerThread}) g
        WHERE r."idempotencyKey" LIKE 'perf:ride:%'
          AND NOT EXISTS (
            SELECT 1 FROM chat_messages m
            WHERE m."threadId" = t.id AND m.body LIKE 'Perf msg%'
          )
        `,
      );
    }

    // Outbox backlog sample
    await db.$executeRawUnsafe(
      `
      INSERT INTO outbox_messages (id, "eventKey", "aggregateType", "aggregateId", "eventType", payload, "createdAt")
      SELECT
        gen_random_uuid(),
        'Ride:' || r.id::text || ':status:' || r.status::text || ':perf',
        'Ride',
        r.id,
        'Ride.status.' || r.status::text,
        jsonb_build_object('status', r.status::text, 'perf', true),
        r."createdAt"
      FROM rides r
      WHERE r."idempotencyKey" LIKE 'perf:ride:%'
        AND r.status IN ('COMPLETED','CANCELLED','EXPIRED')
      ON CONFLICT ("eventKey") DO NOTHING
      `,
    );

    const counts = await db.$queryRawUnsafe<
      Array<{
        users: bigint;
        stores: bigint;
        rides: bigint;
        orders: bigint;
        orderLines: bigint;
        ordersMissingLines: bigint;
        messages: bigint;
      }>
    >(
      `
      SELECT
        (SELECT count(*) FROM users WHERE phone LIKE '+8499%') AS users,
        (SELECT count(*) FROM food_stores WHERE name LIKE 'Perf Store %') AS stores,
        (SELECT count(*) FROM rides WHERE "idempotencyKey" LIKE 'perf:ride:%') AS rides,
        (SELECT count(*) FROM food_orders WHERE "idempotencyKey" LIKE 'perf:food:%') AS orders,
        (SELECT count(*) FROM food_order_lines l
          JOIN food_orders o ON o.id = l."orderId"
          WHERE o."idempotencyKey" LIKE 'perf:food:%') AS "orderLines",
        (SELECT count(*) FROM food_orders o
          WHERE o."idempotencyKey" LIKE 'perf:food:%'
            AND NOT EXISTS (
              SELECT 1 FROM food_order_lines l WHERE l."orderId" = o.id
            )) AS "ordersMissingLines",
        (SELECT count(*) FROM chat_messages WHERE body LIKE 'Perf msg%') AS messages
      `,
    );

    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_customers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_drivers`);
    await db.$executeRawUnsafe(`DROP TABLE IF EXISTS perf_seed_stores`);

    console.log(
      JSON.stringify({
        msg: 'seed-scale.done',
        profile: profile.name,
        elapsedMs: Date.now() - started,
        counts: {
          users: Number(counts[0]?.users ?? 0n),
          stores: Number(counts[0]?.stores ?? 0n),
          rides: Number(counts[0]?.rides ?? 0n),
          orders: Number(counts[0]?.orders ?? 0n),
          orderLines: Number(counts[0]?.orderLines ?? 0n),
          ordersMissingLines: Number(counts[0]?.ordersMissingLines ?? 0n),
          messages: Number(counts[0]?.messages ?? 0n),
        },
      }),
    );
  } finally {
    await db.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
