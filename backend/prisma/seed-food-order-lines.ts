/**
 * Ensure every food order has ≥1 line for admin/detail demo & perf seeds.
 *
 * Steps (idempotent):
 * 1. Create a minimal catalog item on any store that has line-less orders but no food_items.
 * 2. Insert one line per line-less order, priced from subtotalVnd when positive.
 *
 * Usage (heal existing DB):
 *   npx tsx prisma/seed-food-order-lines.ts
 *   npm run seed:heal-food-lines
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';

const DEFAULT_ITEM_NAME = 'Seed Combo';
const DEFAULT_ITEM_PRICE_VND = 45_000;

type SqlClient = Pick<PrismaClient, '$executeRawUnsafe' | '$queryRawUnsafe'>;

export type FoodOrderLinesHealResult = {
  storesEnsuredItems: number;
  linesInserted: number;
  ordersStillMissingLines: number;
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

/**
 * Idempotent: safe to re-run. Scopes to all food_orders missing lines.
 */
export async function ensureFoodOrderLines(db: SqlClient): Promise<FoodOrderLinesHealResult> {
  await db.$executeRawUnsafe(`SET statement_timeout = 0`);

  const ensured = await db.$executeRawUnsafe(
    `
    INSERT INTO food_items (id, "storeId", name, "priceVnd", available)
    SELECT gen_random_uuid(), s.id, '${DEFAULT_ITEM_NAME}', ${DEFAULT_ITEM_PRICE_VND}, true
    FROM food_stores s
    WHERE EXISTS (
      SELECT 1
      FROM food_orders o
      WHERE o."storeId" = s.id
        AND NOT EXISTS (
          SELECT 1 FROM food_order_lines l WHERE l."orderId" = o.id
        )
    )
    AND NOT EXISTS (
      SELECT 1 FROM food_items fi WHERE fi."storeId" = s.id
    )
    `,
  );

  const inserted = await db.$executeRawUnsafe(
    `
    INSERT INTO food_order_lines (id, "orderId", "itemId", name, "unitPriceVnd", quantity)
    SELECT
      gen_random_uuid(),
      o.id,
      fi.id,
      fi.name,
      CASE
        WHEN o."subtotalVnd" > 0 THEN o."subtotalVnd"
        ELSE GREATEST(fi."priceVnd", 1)
      END,
      1
    FROM food_orders o
    JOIN LATERAL (
      SELECT id, name, "priceVnd"
      FROM food_items
      WHERE "storeId" = o."storeId"
      ORDER BY name ASC
      LIMIT 1
    ) fi ON true
    WHERE NOT EXISTS (
      SELECT 1 FROM food_order_lines l WHERE l."orderId" = o.id
    )
    `,
  );

  const missingRows = await db.$queryRawUnsafe<Array<{ c: bigint }>>(
    `
    SELECT count(*)::bigint AS c
    FROM food_orders o
    WHERE NOT EXISTS (
      SELECT 1 FROM food_order_lines l WHERE l."orderId" = o.id
    )
    `,
  );

  return {
    storesEnsuredItems: typeof ensured === 'number' ? ensured : Number(ensured ?? 0),
    linesInserted: typeof inserted === 'number' ? inserted : Number(inserted ?? 0),
    ordersStillMissingLines: Number(missingRows[0]?.c ?? 0n),
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
    const result = await ensureFoodOrderLines(db);
    console.log(
      JSON.stringify({
        msg: 'seed-food-order-lines.done',
        elapsedMs: Date.now() - started,
        ...result,
      }),
    );
    if (result.ordersStillMissingLines > 0) {
      process.exitCode = 1;
    }
  } finally {
    await db.$disconnect();
  }
}

const isDirectRun =
  process.argv[1] !== undefined &&
  (process.argv[1].endsWith('seed-food-order-lines.ts') ||
    process.argv[1].endsWith('seed-food-order-lines.js'));

if (isDirectRun) {
  main().catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
