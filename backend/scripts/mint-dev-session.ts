/**
 * Mint a real DB session + JWT for local/perf only.
 *
 * Usage:
 *   npx tsx scripts/mint-dev-session.ts --phone=+84902000001
 *   npx tsx scripts/mint-dev-session.ts --email=ops@localhost --channel=ops
 *
 * Refuses NODE_ENV=production.
 */
import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

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

function arg(name: string): string | undefined {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx < 0) {
    return undefined;
  }
  return process.argv[idx + 1];
}

function base64url(value: string): string {
  return Buffer.from(value).toString('base64url');
}

function signAccessToken(claims: Record<string, unknown>, secret: string): string {
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64url(JSON.stringify(claims));
  const signature = createHmac('sha256', secret)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${signature}`;
}

async function main(): Promise<void> {
  loadDotEnv();
  if (process.env.NODE_ENV === 'production') {
    throw new Error('mint-dev-session refuses NODE_ENV=production');
  }

  const phone = arg('phone');
  const email = arg('email')?.trim().toLowerCase();
  const channel = (arg('channel') ?? 'customer') as 'customer' | 'ops';
  if (!phone && !email) {
    throw new Error('Pass --phone=+84... or --email=...');
  }
  if (channel !== 'customer' && channel !== 'ops') {
    throw new Error('--channel must be customer|ops');
  }

  const databaseUrl =
    process.env.DATABASE_URL?.trim() ||
    'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';
  const secret =
    process.env.JWT_ACCESS_SECRET?.trim() ||
    process.env.JWT_SECRET?.trim() ||
    'dev-only-change-me';
  const accessTtl = Number(process.env.JWT_ACCESS_TTL_SECONDS ?? 3600);
  const refreshTtl = Number(process.env.JWT_REFRESH_TTL_SECONDS ?? 1_209_600);

  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: databaseUrl }) });
  try {
    const user = phone
      ? await db.user.findUnique({ where: { phone } })
      : await db.user.findUnique({ where: { email: email! } });
    if (!user) {
      throw new Error(`User not found for ${phone ?? email}`);
    }

    const refreshToken = randomBytes(32).toString('base64url');
    const now = new Date();
    const session = await db.session.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        channel: channel === 'ops' ? 'OPS' : 'CUSTOMER',
        refreshTokenHash: createHash('sha256').update(refreshToken).digest('base64url'),
        expiresAt: new Date(now.getTime() + refreshTtl * 1000),
      },
    });

    const iat = Math.floor(now.getTime() / 1000);
    const accessToken = signAccessToken(
      { sub: user.id, sid: session.id, ch: channel, iat, exp: iat + accessTtl },
      secret,
    );

    process.stdout.write(
      JSON.stringify(
        {
          accessToken,
          refreshToken,
          expiresIn: accessTtl,
          user: { id: user.id, phone: user.phone, email: user.email },
          channel,
        },
        null,
        2,
      ) + '\n',
    );
  } finally {
    await db.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
