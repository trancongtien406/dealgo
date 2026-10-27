/**
 * Ops CLI for sign-in method toggles (DEC-PROD-051). Use it when the API refuses to start in
 * production because an ENABLED method has no provider configured (e.g. SMS keys not issued yet):
 *
 *   npm run auth-methods -- list
 *   npm run auth-methods -- disable PHONE_SMS
 *   npm run auth-methods -- enable PASSKEY
 *
 * Methods: PASSKEY, PHONE_SMS, EMAIL_LOGIN_IDENTIFIER. Reads DATABASE_URL from env / .env.
 * Normal changes belong in Admin → Phương thức đăng nhập (audited); this is the break-glass path.
 */
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

const METHODS = ['PASSKEY', 'PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER'] as const;
type Method = (typeof METHODS)[number];

async function main(): Promise<void> {
  const envFile = resolve(process.cwd(), '.env');
  if (!process.env.DATABASE_URL && existsSync(envFile)) process.loadEnvFile(envFile);
  const [command = 'list', rawMethod] = process.argv.slice(2);
  const db = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }),
  });
  try {
    if (command === 'enable' || command === 'disable') {
      const method = rawMethod?.toUpperCase() as Method;
      if (!METHODS.includes(method)) {
        throw new Error(`Unknown method "${rawMethod ?? ''}". Use one of: ${METHODS.join(', ')}`);
      }
      const enabled = command === 'enable';
      await db.authMethodPolicy.upsert({
        where: { method },
        create: { method, enabled },
        update: { enabled, updatedByUserId: null },
      });
    } else if (command !== 'list') {
      throw new Error('Usage: auth-methods [list | enable <METHOD> | disable <METHOD>]');
    }
    const rows = await db.authMethodPolicy.findMany({ orderBy: { method: 'asc' } });
    const state = new Map(rows.map((r) => [r.method, r.enabled]));
    for (const m of METHODS) console.log(`${m}\t${state.get(m) ?? true ? 'enabled' : 'disabled'}`);
  } finally {
    await db.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
