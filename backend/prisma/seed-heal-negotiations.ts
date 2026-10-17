/**
 * Ensure ~8–12 NEGOTIATING rides with 1–3 pending offers for admin bid UI demos.
 *
 * Scale seeds age open rides to EXPIRED; this heal recreates a small fixed set
 * under `heal:ride:negotiating:*` using existing CUSTOMER/DRIVER users.
 *
 * Usage:
 *   npx tsx prisma/seed-heal-negotiations.ts
 *   npm run seed:heal-negotiations
 *
 * Prefer running after `seed:scale` (also invoked at end of seed-scale.ts).
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';

/** Fixed slot count — within the ~8–12 demo target. */
const TARGET_SLOTS = 10;

const HEAL_KEY_PREFIX = 'heal:ride:negotiating:';

type SqlClient = Pick<PrismaClient, '$executeRawUnsafe' | '$queryRawUnsafe'>;

export type NegotiationsHealResult = {
  revived: number;
  inserted: number;
  expiryRefreshed: number;
  offersUpserted: number;
  negotiatingTotal: number;
  healNegotiating: number;
  offersOnHealRides: number;
};

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

function healKey(slot: number): string {
  return `${HEAL_KEY_PREFIX}${String(slot).padStart(2, '0')}`;
}

/**
 * Idempotent: safe to re-run. Keeps heal-keyed rides open with pending offers.
 */
export async function ensureNegotiatingRides(
  db: SqlClient,
): Promise<NegotiationsHealResult> {
  await db.$executeRawUnsafe(`SET statement_timeout = 0`);

  const revived = await db.$executeRawUnsafe(
    `
    UPDATE rides r
    SET
      status = 'NEGOTIATING'::"RideStatus",
      "expiresAt" = now() + interval '7 days',
      "assignedDriverId" = NULL,
      "selectedOfferId" = NULL,
      "agreedFareVnd" = NULL,
      "updatedAt" = now()
    WHERE r."idempotencyKey" LIKE '${HEAL_KEY_PREFIX}%'
      AND r.status IN ('EXPIRED'::"RideStatus", 'CANCELLED'::"RideStatus")
      AND NOT EXISTS (
        SELECT 1
        FROM rides o
        WHERE o."customerId" = r."customerId"
          AND o.status = 'NEGOTIATING'::"RideStatus"
          AND o.id <> r.id
      )
    `,
  );

  const inserted = await db.$executeRawUnsafe(
    `
    WITH wanted AS (
      SELECT generate_series(1, ${TARGET_SLOTS}) AS slot
    ),
    missing AS (
      SELECT w.slot, row_number() OVER (ORDER BY w.slot) AS rn
      FROM wanted w
      WHERE NOT EXISTS (
        SELECT 1
        FROM rides r
        WHERE r."idempotencyKey" = '${HEAL_KEY_PREFIX}' || lpad(w.slot::text, 2, '0')
      )
    ),
    customers AS (
      SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
      FROM users u
      JOIN role_grants rg
        ON rg."userId" = u.id
       AND rg.role = 'CUSTOMER'::"Role"
       AND rg.status = 'ACTIVE'::"RoleGrantStatus"
      WHERE NOT EXISTS (
        SELECT 1
        FROM rides r
        WHERE r."customerId" = u.id
          AND r.status = 'NEGOTIATING'::"RideStatus"
      )
    ),
    places AS (
      SELECT *
      FROM (
        VALUES
          (1, 16.0682, 108.2241, 'Chợ Hàn, Hải Châu', 16.0597, 108.2435, 'Bãi biển Mỹ Khê'),
          (2, 16.0611, 108.2272, 'Cầu Rồng, Hải Châu', 16.0538, 108.2022, 'Sân bay Đà Nẵng'),
          (3, 16.0828, 108.2443, 'Bán đảo Sơn Trà', 16.0611, 108.2272, 'Cầu Rồng'),
          (4, 16.0544, 108.2022, 'Ga Đà Nẵng', 16.0682, 108.2241, 'Chợ Hàn, Hải Châu'),
          (5, 16.0472, 108.2208, 'Nhà thờ Con Gà, Hải Châu', 16.0022, 108.2638, 'Ngũ Hành Sơn'),
          (6, 16.0712, 108.2235, 'Bạch Đằng, Hải Châu', 16.0597, 108.2435, 'Mỹ Khê'),
          (7, 16.0665, 108.2200, 'Trần Phú, Hải Châu', 16.0828, 108.2443, 'Sơn Trà'),
          (8, 16.0600, 108.2150, 'Lê Duẩn, Hải Châu', 16.0472, 108.2208, 'Nhà thờ Con Gà'),
          (9, 16.0750, 108.2300, 'An Thượng, Ngũ Hành Sơn', 16.0682, 108.2241, 'Chợ Hàn'),
          (10, 16.0550, 108.2350, 'Phạm Văn Đồng', 16.0538, 108.2022, 'Sân bay Đà Nẵng')
      ) AS t(
        slot,
        pickup_lat, pickup_lng, pickup_label,
        dropoff_lat, dropoff_lng, dropoff_label
      )
    )
    INSERT INTO rides (
      id, "customerId",
      "pickupLat", "pickupLng", "pickupLabel",
      "dropoffLat", "dropoffLng", "dropoffLabel",
      "offeredFareVnd", "referenceFareVnd",
      status, "expiresAt", "idempotencyKey",
      "createdAt", "updatedAt"
    )
    SELECT
      gen_random_uuid(),
      c.id,
      p.pickup_lat, p.pickup_lng, p.pickup_label,
      p.dropoff_lat, p.dropoff_lng, p.dropoff_label,
      35000 + ((m.slot - 1) % 5) * 4000,
      38000 + ((m.slot - 1) % 5) * 4000,
      'NEGOTIATING'::"RideStatus",
      now() + interval '7 days',
      '${HEAL_KEY_PREFIX}' || lpad(m.slot::text, 2, '0'),
      now(),
      now()
    FROM missing m
    JOIN customers c ON c.rn = m.rn
    JOIN places p ON p.slot = m.slot
    `,
  );

  const expiryRefreshed = await db.$executeRawUnsafe(
    `
    UPDATE rides
    SET
      "expiresAt" = now() + interval '7 days',
      "updatedAt" = now()
    WHERE status = 'NEGOTIATING'::"RideStatus"
      AND "idempotencyKey" LIKE '${HEAL_KEY_PREFIX}%'
      AND "expiresAt" < now() + interval '6 days'
    `,
  );

  const offersUpserted = await db.$executeRawUnsafe(
    `
    WITH heal_rides AS (
      SELECT
        r.id,
        r."offeredFareVnd",
        r."customerId",
        row_number() OVER (ORDER BY r."idempotencyKey") AS rn
      FROM rides r
      WHERE r.status = 'NEGOTIATING'::"RideStatus"
        AND r."idempotencyKey" LIKE '${HEAL_KEY_PREFIX}%'
    ),
    drivers AS (
      SELECT u.id, row_number() OVER (ORDER BY u.phone) AS rn
      FROM users u
      JOIN role_grants rg
        ON rg."userId" = u.id
       AND rg.role = 'DRIVER'::"Role"
       AND rg.status = 'ACTIVE'::"RoleGrantStatus"
    ),
    driver_count AS (
      SELECT greatest(count(*)::int, 1) AS n FROM drivers
    ),
    offer_plan AS (
      SELECT
        hr.id AS ride_id,
        d.id AS driver_id,
        greatest(
          hr."offeredFareVnd" + ((o.off_idx - 2) * 2000),
          1000
        ) AS amount_vnd,
        CASE
          WHEN o.off_idx = 1 THEN 'ACCEPT'::"RideOfferKind"
          ELSE 'COUNTER'::"RideOfferKind"
        END AS kind
      FROM heal_rides hr
      CROSS JOIN LATERAL generate_series(1, 1 + ((hr.rn - 1) % 3)) AS o(off_idx)
      CROSS JOIN driver_count dc
      JOIN drivers d
        ON d.rn = 1 + (((hr.rn - 1) * 3 + o.off_idx - 1) % dc.n)
      WHERE d.id <> hr."customerId"
    )
    INSERT INTO ride_offers (
      id, "rideId", "driverId", "amountVnd", kind, status, "expiresAt",
      "createdAt", "updatedAt"
    )
    SELECT
      gen_random_uuid(),
      op.ride_id,
      op.driver_id,
      op.amount_vnd,
      op.kind,
      'PENDING'::"RideOfferStatus",
      now() + interval '7 days',
      now(),
      now()
    FROM offer_plan op
    ON CONFLICT ("rideId", "driverId") DO UPDATE
    SET
      "expiresAt" = EXCLUDED."expiresAt",
      status = 'PENDING'::"RideOfferStatus",
      "updatedAt" = now()
    `,
  );

  const counts = await db.$queryRawUnsafe<
    Array<{
      negotiatingTotal: bigint;
      healNegotiating: bigint;
      offersOnHealRides: bigint;
    }>
  >(
    `
    SELECT
      (SELECT count(*)::bigint FROM rides WHERE status = 'NEGOTIATING'::"RideStatus")
        AS "negotiatingTotal",
      (SELECT count(*)::bigint
       FROM rides
       WHERE status = 'NEGOTIATING'::"RideStatus"
         AND "idempotencyKey" LIKE '${HEAL_KEY_PREFIX}%')
        AS "healNegotiating",
      (SELECT count(*)::bigint
       FROM ride_offers o
       JOIN rides r ON r.id = o."rideId"
       WHERE r.status = 'NEGOTIATING'::"RideStatus"
         AND r."idempotencyKey" LIKE '${HEAL_KEY_PREFIX}%')
        AS "offersOnHealRides"
    `,
  );

  const row = counts[0];
  return {
    revived: typeof revived === 'number' ? revived : Number(revived ?? 0),
    inserted: typeof inserted === 'number' ? inserted : Number(inserted ?? 0),
    expiryRefreshed:
      typeof expiryRefreshed === 'number'
        ? expiryRefreshed
        : Number(expiryRefreshed ?? 0),
    offersUpserted:
      typeof offersUpserted === 'number'
        ? offersUpserted
        : Number(offersUpserted ?? 0),
    negotiatingTotal: Number(row?.negotiatingTotal ?? 0n),
    healNegotiating: Number(row?.healNegotiating ?? 0n),
    offersOnHealRides: Number(row?.offersOnHealRides ?? 0n),
  };
}

async function main(): Promise<void> {
  loadDotEnv();
  const db = new PrismaClient({
    adapter: new PrismaPg({
      connectionString: process.env.DATABASE_URL?.trim() || LOCAL_DATABASE_URL,
    }),
  });

  try {
    const started = Date.now();
    const result = await ensureNegotiatingRides(db);
    console.log(
      JSON.stringify({
        msg: 'seed-heal-negotiations.done',
        elapsedMs: Date.now() - started,
        targetSlots: TARGET_SLOTS,
        healKeys: Array.from({ length: TARGET_SLOTS }, (_, i) => healKey(i + 1)),
        ...result,
      }),
    );
    if (result.healNegotiating < 8 || result.offersOnHealRides < 8) {
      process.exitCode = 1;
    }
  } finally {
    await db.$disconnect();
  }
}

const isDirectRun =
  process.argv[1] !== undefined &&
  (process.argv[1].endsWith('seed-heal-negotiations.ts') ||
    process.argv[1].endsWith('seed-heal-negotiations.js'));

if (isDirectRun) {
  main().catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
