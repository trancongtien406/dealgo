/**
 * Backfill serviceRegionCode on rides, food_orders, food_stores, driver_presence.
 *
 * Order: bbox from lat/lng → label heuristics → DEFAULT DN for remaining nulls.
 * Idempotent: only updates rows where serviceRegionCode IS NULL (or --force).
 *
 * Usage:
 *   npm run seed:heal-regions
 *   npx tsx prisma/seed-heal-regions.ts --force
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import {
  DEFAULT_SERVICE_REGION_CODE,
  SERVICE_REGIONS,
} from '../src/modules/service-area/service-regions.js';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';

type SqlClient = Pick<PrismaClient, '$executeRawUnsafe' | '$queryRawUnsafe'>;

export type RegionsHealResult = {
  ridesBbox: number;
  ridesLabel: number;
  ridesDefault: number;
  foodOrdersBbox: number;
  foodOrdersLabel: number;
  foodOrdersDefault: number;
  storesBbox: number;
  storesDefault: number;
  presenceBbox: number;
  presenceDefault: number;
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

function nullPredicate(force: boolean): string {
  return force ? 'TRUE' : `"serviceRegionCode" IS NULL`;
}

async function backfillRidesByBbox(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  let total = 0;
  const pred = nullPredicate(force);
  for (const region of SERVICE_REGIONS) {
    const { minLat, maxLat, minLng, maxLng } = region.bbox;
    const n = await db.$executeRawUnsafe(
      `
      UPDATE rides
      SET "serviceRegionCode" = $1
      WHERE (${pred})
        AND "pickupLat" BETWEEN $2 AND $3
        AND "pickupLng" BETWEEN $4 AND $5
      `,
      region.code,
      minLat,
      maxLat,
      minLng,
      maxLng,
    );
    total += Number(n);
  }
  return total;
}

async function backfillFoodOrdersByBbox(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  let total = 0;
  const pred = nullPredicate(force);
  for (const region of SERVICE_REGIONS) {
    const { minLat, maxLat, minLng, maxLng } = region.bbox;
    const n = await db.$executeRawUnsafe(
      `
      UPDATE food_orders
      SET "serviceRegionCode" = $1
      WHERE (${pred})
        AND "dropoffLat" BETWEEN $2 AND $3
        AND "dropoffLng" BETWEEN $4 AND $5
      `,
      region.code,
      minLat,
      maxLat,
      minLng,
      maxLng,
    );
    total += Number(n);
  }
  return total;
}

async function backfillStoresByBbox(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  let total = 0;
  const pred = nullPredicate(force);
  for (const region of SERVICE_REGIONS) {
    const { minLat, maxLat, minLng, maxLng } = region.bbox;
    const n = await db.$executeRawUnsafe(
      `
      UPDATE food_stores
      SET "serviceRegionCode" = $1
      WHERE (${pred})
        AND lat IS NOT NULL AND lng IS NOT NULL
        AND lat BETWEEN $2 AND $3
        AND lng BETWEEN $4 AND $5
      `,
      region.code,
      minLat,
      maxLat,
      minLng,
      maxLng,
    );
    total += Number(n);
  }
  return total;
}

async function backfillPresenceByBbox(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  let total = 0;
  const pred = nullPredicate(force);
  for (const region of SERVICE_REGIONS) {
    const { minLat, maxLat, minLng, maxLng } = region.bbox;
    const n = await db.$executeRawUnsafe(
      `
      UPDATE driver_presence
      SET "serviceRegionCode" = $1
      WHERE (${pred})
        AND lat IS NOT NULL AND lng IS NOT NULL
        AND lat BETWEEN $2 AND $3
        AND lng BETWEEN $4 AND $5
      `,
      region.code,
      minLat,
      maxLat,
      minLng,
      maxLng,
    );
    total += Number(n);
  }
  return total;
}

/** Label backfill for rides still null after bbox. */
async function backfillRidesByLabel(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  const pred = nullPredicate(force);
  const steps: Array<{ code: string; sql: string }> = [
    {
      code: 'HCM',
      sql: `
        UPDATE rides SET "serviceRegionCode" = 'HCM'
        WHERE (${pred})
          AND (
            "pickupLabel" ILIKE '%Hồ Chí Minh%' OR "pickupLabel" ILIKE '%Ho Chi Minh%'
            OR "pickupLabel" ILIKE '%HCM%' OR "pickupLabel" ILIKE '%Sài Gòn%'
            OR "dropoffLabel" ILIKE '%Hồ Chí Minh%' OR "dropoffLabel" ILIKE '%Ho Chi Minh%'
            OR "dropoffLabel" ILIKE '%HCM%' OR "dropoffLabel" ILIKE '%Sài Gòn%'
          )`,
    },
    {
      code: 'HN',
      sql: `
        UPDATE rides SET "serviceRegionCode" = 'HN'
        WHERE (${pred})
          AND (
            "pickupLabel" ILIKE '%Hà Nội%' OR "pickupLabel" ILIKE '%Ha Noi%'
            OR "dropoffLabel" ILIKE '%Hà Nội%' OR "dropoffLabel" ILIKE '%Ha Noi%'
          )`,
    },
    {
      code: 'HP',
      sql: `
        UPDATE rides SET "serviceRegionCode" = 'HP'
        WHERE (${pred})
          AND (
            "pickupLabel" ILIKE '%Hải Phòng%' OR "pickupLabel" ILIKE '%Hai Phong%'
            OR "dropoffLabel" ILIKE '%Hải Phòng%' OR "dropoffLabel" ILIKE '%Hai Phong%'
          )`,
    },
    {
      code: 'DN',
      sql: `
        UPDATE rides SET "serviceRegionCode" = 'DN'
        WHERE (${pred})
          AND (
            "pickupLabel" ILIKE '%Đà Nẵng%' OR "pickupLabel" ILIKE '%Da Nang%'
            OR "pickupLabel" ILIKE '%Hải Châu%' OR "pickupLabel" ILIKE '%Sơn Trà%'
            OR "pickupLabel" ILIKE '%Thanh Khê%' OR "pickupLabel" ILIKE '%Ngũ Hành Sơn%'
            OR "dropoffLabel" ILIKE '%Đà Nẵng%' OR "dropoffLabel" ILIKE '%Da Nang%'
            OR "dropoffLabel" ILIKE '%Hải Châu%' OR "dropoffLabel" ILIKE '%Sơn Trà%'
            OR "dropoffLabel" ILIKE '%Thanh Khê%' OR "dropoffLabel" ILIKE '%Hội An%'
          )`,
    },
  ];
  let total = 0;
  for (const step of steps) {
    total += Number(await db.$executeRawUnsafe(step.sql));
  }
  return total;
}

async function backfillFoodOrdersByLabel(
  db: SqlClient,
  force: boolean,
): Promise<number> {
  const pred = nullPredicate(force);
  const steps = [
    `UPDATE food_orders SET "serviceRegionCode" = 'HCM'
     WHERE (${pred}) AND (
       "dropoffLabel" ILIKE '%Hồ Chí Minh%' OR "dropoffLabel" ILIKE '%Ho Chi Minh%'
       OR "dropoffLabel" ILIKE '%HCM%' OR "dropoffLabel" ILIKE '%Sài Gòn%'
     )`,
    `UPDATE food_orders SET "serviceRegionCode" = 'HN'
     WHERE (${pred}) AND (
       "dropoffLabel" ILIKE '%Hà Nội%' OR "dropoffLabel" ILIKE '%Ha Noi%'
     )`,
    `UPDATE food_orders SET "serviceRegionCode" = 'HP'
     WHERE (${pred}) AND (
       "dropoffLabel" ILIKE '%Hải Phòng%' OR "dropoffLabel" ILIKE '%Hai Phong%'
     )`,
    `UPDATE food_orders SET "serviceRegionCode" = 'DN'
     WHERE (${pred}) AND (
       "dropoffLabel" ILIKE '%Đà Nẵng%' OR "dropoffLabel" ILIKE '%Da Nang%'
       OR "dropoffLabel" ILIKE '%Hải Châu%' OR "dropoffLabel" ILIKE '%Sơn Trà%'
       OR "dropoffLabel" ILIKE '%Thanh Khê%' OR "dropoffLabel" ILIKE '%Hội An%'
     )`,
  ];
  let total = 0;
  for (const sql of steps) {
    total += Number(await db.$executeRawUnsafe(sql));
  }
  return total;
}

async function defaultRemaining(
  db: SqlClient,
  table: string,
  force: boolean,
): Promise<number> {
  const pred = nullPredicate(force);
  return Number(
    await db.$executeRawUnsafe(
      `UPDATE ${table} SET "serviceRegionCode" = $1 WHERE (${pred})`,
      DEFAULT_SERVICE_REGION_CODE,
    ),
  );
}

export async function healServiceRegions(
  db: SqlClient,
  options: { force?: boolean } = {},
): Promise<RegionsHealResult> {
  const force = options.force === true;
  await db.$executeRawUnsafe(`SET statement_timeout = 0`);

  if (force) {
    await db.$executeRawUnsafe(`UPDATE rides SET "serviceRegionCode" = NULL`);
    await db.$executeRawUnsafe(`UPDATE food_orders SET "serviceRegionCode" = NULL`);
    await db.$executeRawUnsafe(`UPDATE food_stores SET "serviceRegionCode" = NULL`);
    await db.$executeRawUnsafe(`UPDATE driver_presence SET "serviceRegionCode" = NULL`);
  }

  // After optional clear, only fill nulls so later stages never clobber bbox/label wins.
  const ridesBbox = await backfillRidesByBbox(db, false);
  const ridesLabel = await backfillRidesByLabel(db, false);
  const ridesDefault = await defaultRemaining(db, 'rides', false);

  const foodOrdersBbox = await backfillFoodOrdersByBbox(db, false);
  const foodOrdersLabel = await backfillFoodOrdersByLabel(db, false);
  const foodOrdersDefault = await defaultRemaining(db, 'food_orders', false);

  const storesBbox = await backfillStoresByBbox(db, false);
  const storesDefault = await defaultRemaining(db, 'food_stores', false);

  const presenceBbox = await backfillPresenceByBbox(db, false);
  const presenceDefault = await defaultRemaining(db, 'driver_presence', false);

  return {
    ridesBbox,
    ridesLabel,
    ridesDefault,
    foodOrdersBbox,
    foodOrdersLabel,
    foodOrdersDefault,
    storesBbox,
    storesDefault,
    presenceBbox,
    presenceDefault,
  };
}

async function main(): Promise<void> {
  loadDotEnv();
  const force = process.argv.includes('--force');
  const url = process.env.DATABASE_URL?.trim() || LOCAL_DATABASE_URL;
  process.env.DATABASE_URL = url;

  const adapter = new PrismaPg({ connectionString: url });
  const prisma = new PrismaClient({ adapter });

  try {
    const result = await healServiceRegions(prisma, { force });
    console.log(
      JSON.stringify(
        {
          force,
          defaultCode: DEFAULT_SERVICE_REGION_CODE,
          ...result,
        },
        null,
        2,
      ),
    );
  } finally {
    await prisma.$disconnect();
  }
}

const isDirectRun =
  process.argv[1]?.includes('seed-heal-regions') ||
  process.argv[1]?.endsWith('seed-heal-regions.ts');

if (isDirectRun) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
