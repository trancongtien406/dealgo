import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { signAccessToken, accessSecret, unixSeconds, randomSecret, hashRefreshToken } from '../src/platform/security/token-crypto.js';
import { randomUUID } from 'node:crypto';
import 'dotenv/config';

const db = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }),
});

async function main() {
  const user = await db.user.findFirst({
    where: { phone: '+84902000001' },
  });
  if (!user) {
    console.error('Customer user not found');
    process.exit(1);
  }

  const sessionId = randomUUID();
  const familyId = randomUUID();
  const refreshToken = randomSecret();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 14 * 86400 * 1000);

  await db.session.create({
    data: {
      id: sessionId,
      userId: user.id,
      familyId,
      channel: 'CUSTOMER',
      refreshTokenHash: hashRefreshToken(refreshToken),
      expiresAt,
    },
  });

  const issuedAt = unixSeconds(now);
  const expiresIn = 3600 * 24 * 7; // 7 days
  const secret = accessSecret({
    JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET,
    NODE_ENV: process.env.NODE_ENV,
  });

  const accessToken = signAccessToken(
    {
      sub: user.id,
      sid: sessionId,
      ch: 'customer',
      iat: issuedAt,
      exp: issuedAt + expiresIn,
    },
    secret,
  );

  console.log('JSON_OUTPUT=' + JSON.stringify({ accessToken, refreshToken, userId: user.id, phone: user.phone, name: user.displayName }));
  await db.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
