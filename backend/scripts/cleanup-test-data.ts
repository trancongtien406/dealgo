/**
 * DEV-only: deletes perf/pg-test leftovers (marker-identified users) and their rides/food/stores,
 * children first, in one tx. Dry-run by default (runs in tx then rolls back); --apply commits.
 * Usage: npx tsx scripts/cleanup-test-data.ts [--apply] [--e2e]
 * --e2e also removes simulator/ops test accounts: E2E_PHONES and `sa-*` / `ops-ride-voucher-*` @dealgo.test emails.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

for (const raw of existsSync(resolve('.env')) ? readFileSync(resolve('.env'), 'utf8').split('\n') : []) {
  const line = raw.trim();
  if (!line || line.startsWith('#') || !line.includes('=')) continue;
  const eq = line.indexOf('=');
  const k = line.slice(0, eq).trim();
  if (process.env[k] === undefined) process.env[k] = line.slice(eq + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
}
const apply = process.argv.includes('--apply');
const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });

/** displayNames used by test/concurrency/*.pg.spec.ts (all created with email = null). */
const PG_NAMES = ['DealGo user', 'Stats Customer', 'Stats Owner', 'Stats Driver', 'pickup-code-pg', 'Del Driver', 'Del Ops', 'Del Owner',
  'Del Staff', 'Del Customer', 'Hours Customer', 'Idle Driver', 'A', 'B', 'C', 'Location New', 'Location Test', 'Người dùng đã xoá',
  'Night Owner', 'Option Customer', 'Option Customer 2', 'Option Owner', 'Option Owner 2', 'Orphan Test', 'Other Owner', 'Pause Customer',
  'Pause Owner', 'Cap Customer 0', 'Cap Customer 1', 'Cap Customer 2', 'Cap Customer 3', 'Cap Customer 4', 'Cap Customer 5', 'Cap Owner',
  'Race Applicant', 'Race Ops', 'Restore Ops', 'support-pg', 'support-pg-flow', 'support-pg-staff', 'Toggle Test', 'Code Customer', 'Code Owner'];
/** E2E onboarding sim users (KYC driver / KYB merchant). */
const E2E_PHONES = ['+84909990071', '+84909990072'];
const SEED_PHONES = ['+84902000001', '+84903000001', '+84901110001'];

async function main() {
  const url = new URL(process.env.DATABASE_URL ?? '');
  if (!['localhost', '127.0.0.1', '::1'].includes(url.hostname)) throw new Error(`refused: host ${url.hostname} not local`);
  const ids = async (sql: string, ...p: unknown[]) => ((await db.$queryRawUnsafe(sql, ...p)) as { id: string }[]).map((r) => r.id);
  const users = await ids(`select id::text id from users where
      (("displayName" like 'Perf User %' and email like 'perf.user.%@example.invalid')
       or (email is null and "displayName" = any($1)))
      and coalesce(phone,'') <> all($2) and coalesce(email,'') not like '%@seed.dealgo.local'`, PG_NAMES, SEED_PHONES);
  if (process.argv.includes('--e2e')) {
    users.push(...(await ids(`select id::text id from users where phone = any($1)
        or email ~ '^(sa-(root|staff|none)-[0-9a-f]{8}|ops-ride-voucher-[0-9]+)@dealgo\\.test$'`, E2E_PHONES)));
  }
  const stores = await ids(`select id::text id from food_stores where "ownerId"::text = any($1) or name like 'Perf Store %'`, users);
  const rides = await ids(`select id::text id from rides where "customerId"::text = any($1) or "assignedDriverId"::text = any($1)
    or id in (select "rideId" from ride_offers where "driverId"::text = any($1))`, users);
  const foods = await ids(`select id::text id from food_orders where "customerId"::text = any($1) or "assignedDriverId"::text = any($1) or "storeId"::text = any($2)`, users, stores);
  const ents = [...rides, ...foods];
  console.log(`${apply ? 'APPLY' : 'DRY-RUN'} db=${url.hostname}:${url.port}${url.pathname} users=${users.length} rides=${rides.length} foodOrders=${foods.length} stores=${stores.length}`);
  const steps: [string, string, unknown[]][] = [
    ['ledger_entries', `delete from ledger_entries where "journalId" in (select id from ledger_journals where "entityId"::text = any($1))`, [ents]],
    ['ledger_journals', `delete from ledger_journals where "entityId"::text = any($1)`, [ents]],
    ['job_earnings', `delete from job_earnings where "entityId"::text = any($1) or "driverId"::text = any($2)`, [ents, users]],
    ['payment_intents', `delete from payment_intents where "entityId"::text = any($1)`, [ents]],
    ['promotion_redemptions', `delete from promotion_redemptions where "entityId"::text = any($1) or "userId"::text = any($2)`, [ents, users]],
    ['service_ratings', `delete from service_ratings where "subjectId"::text = any($1) or "raterId"::text = any($2) or "driverId"::text = any($2) or "storeId"::text = any($3)`, [ents, users, stores]],
    ['ops_audit_logs', `delete from ops_audit_logs where "entityId"::text = any($1) or "actorUserId"::text = any($2)`, [ents, users]],
    ['chat_messages', `delete from chat_messages where "senderUserId"::text = any($1) or "threadId" in (select id from chat_threads where "rideId"::text = any($2) or "foodOrderId"::text = any($2))`, [users, ents]],
    ['ride_selections', `delete from ride_selections where "rideId"::text = any($1) or "customerId"::text = any($2)`, [rides, users]],
    ['rides.selectedOfferId=null', `update rides set "selectedOfferId" = null where id::text = any($1)`, [rides]],
    ['ride_offers', `delete from ride_offers where "rideId"::text = any($1) or "driverId"::text = any($2)`, [rides, users]],
    ['rides', `delete from rides where id::text = any($1)`, [rides]],
    ['food_orders', `delete from food_orders where id::text = any($1)`, [foods]],
    ['food_stores', `delete from food_stores where id::text = any($1)`, [stores]],
    ['driver_fee_settlements', `delete from driver_fee_settlements where "driverId"::text = any($1) or "actorUserId"::text = any($1)`, [users]],
    ['users', `delete from users where id::text = any($1)`, [users]],
  ];
  const report: Record<string, number> = {};
  try {
    await db.$transaction(async (tx) => {
      for (const [name, sql, p] of steps) report[name] = await tx.$executeRawUnsafe(sql, ...p);
      if (!apply) throw new Error('__dry_run__');
    }, { timeout: 300_000 });
  } catch (e) {
    if (String(e).indexOf('__dry_run__') < 0) throw e;
  }
  console.log(JSON.stringify(report));
}
main().finally(() => db.$disconnect());
