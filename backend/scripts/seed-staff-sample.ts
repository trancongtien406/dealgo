/**
 * DEV-only (t61u): sample staff rows for the admin "Nhân sự" page.
 * Idempotent (upsert by email). Every row is marked: displayName starts with "[MẪU]" and the
 * email ends with "@sample.dealgo.local". No password is set (passwordHash = null) → these
 * accounts cannot sign in; nothing secret is created or printed.
 *
 * Seed:    npx tsx scripts/seed-staff-sample.ts
 * Remove:  npx tsx scripts/seed-staff-sample.ts --remove
 * Refuses any non-local DATABASE_URL host unless SEED_STAFF_SAMPLE_ALLOW_REMOTE=1 (prod, owner-approved).
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

export const SAMPLE_STAFF_DOMAIN = '@sample.dealgo.local';
export const SAMPLE_STAFF_PREFIX = '[MẪU]';

type Sample = {
  key: string;
  name: string;
  staffRole: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE';
  status: 'ACTIVE' | 'PENDING' | 'SUSPENDED';
  credential: boolean;
};

const SAMPLES: Sample[] = [
  { key: 'admin', name: 'Nguyễn Minh Quản trị', staffRole: 'ADMIN', status: 'ACTIVE', credential: true },
  { key: 'ops1', name: 'Trần Thu Vận hành', staffRole: 'OPERATIONS', status: 'ACTIVE', credential: true },
  { key: 'ops2', name: 'Lê Quốc Điều phối', staffRole: 'OPERATIONS', status: 'ACTIVE', credential: true },
  { key: 'support1', name: 'Phạm Hà Hỗ trợ', staffRole: 'SUPPORT', status: 'ACTIVE', credential: true },
  { key: 'support2', name: 'Võ An CSKH', staffRole: 'SUPPORT', status: 'PENDING', credential: false },
  { key: 'finance', name: 'Đặng Lan Kế toán', staffRole: 'FINANCE', status: 'ACTIVE', credential: true },
  { key: 'kyc', name: 'Bùi Khoa Duyệt KYC', staffRole: 'OPERATIONS', status: 'ACTIVE', credential: true },
  { key: 'invite', name: 'Hoàng Nam Mới mời', staffRole: 'SUPPORT', status: 'PENDING', credential: false },
  { key: 'left', name: 'Đỗ Mai Tạm khoá', staffRole: 'OPERATIONS', status: 'SUSPENDED', credential: true },
];

const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });

async function main() {
  const url = new URL(process.env.DATABASE_URL ?? '');
  // Prod opt-in (owner-approved t61u): SEED_STAFF_SAMPLE_ALLOW_REMOTE=1. Rows stay labelled + removable.
  const allowRemote = process.env.SEED_STAFF_SAMPLE_ALLOW_REMOTE === '1';
  if (!allowRemote && !['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
    throw new Error(`refused: host ${url.hostname} is not local (DEV only)`);
  }
  if (process.argv.includes('--remove')) {
    const removed = await db.user.deleteMany({
      where: { email: { endsWith: SAMPLE_STAFF_DOMAIN }, displayName: { startsWith: SAMPLE_STAFF_PREFIX } },
    });
    console.log(`removed ${removed.count} sample staff`);
    return;
  }
  for (const s of SAMPLES) {
    const email = `sample.staff.${s.key}${SAMPLE_STAFF_DOMAIN}`;
    const displayName = `${SAMPLE_STAFF_PREFIX} ${s.name}`;
    const user = await db.user.upsert({
      where: { email },
      update: { displayName },
      create: { email, displayName, emailVerifiedAt: new Date() },
    });
    await db.roleGrant.upsert({
      where: { userId_role: { userId: user.id, role: 'OPS' } },
      update: { status: s.status },
      create: { userId: user.id, role: 'OPS', status: s.status },
    });
    if (s.credential) {
      await db.opsCredential.upsert({
        where: { userId: user.id },
        update: { staffRole: s.staffRole, superAdmin: false },
        create: { userId: user.id, staffRole: s.staffRole, superAdmin: false, passwordHash: null },
      });
    } else {
      await db.opsCredential.deleteMany({ where: { userId: user.id } });
    }
  }
  console.log(`seeded ${SAMPLES.length} sample staff (${SAMPLE_STAFF_PREFIX} … ${SAMPLE_STAFF_DOMAIN})`);
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => db.$disconnect());
