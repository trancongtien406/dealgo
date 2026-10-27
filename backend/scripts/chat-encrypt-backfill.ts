/**
 * DEV/ops backfill: encrypt legacy plaintext chat bodies and re-encrypt rows on old key versions.
 * Requires DATABASE_URL + CHAT_ENCRYPTION_KEY (+ CHAT_ENCRYPTION_PREVIOUS_KEYS for rotation).
 * Prints counts only — never message content or keys.
 * Usage: npx tsx scripts/chat-encrypt-backfill.ts [--dry-run] [--thread-id <uuid>]
 */
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client.js';
import { chatAad, chatCipherFromEnv } from '../src/modules/communication/chat/chat-cipher.js';

async function main(): Promise<void> {
  const envFile = resolve(process.cwd(), '.env');
  if (!process.env.CHAT_ENCRYPTION_KEY && existsSync(envFile)) process.loadEnvFile(envFile);
  const dryRun = process.argv.includes('--dry-run');
  const threadIdx = process.argv.indexOf('--thread-id');
  const threadId = threadIdx > 0 ? process.argv[threadIdx + 1] : undefined;
  const cipher = chatCipherFromEnv({
    NODE_ENV: 'production',
    CHAT_ENCRYPTION_KEY: process.env.CHAT_ENCRYPTION_KEY,
    CHAT_ENCRYPTION_KEY_VERSION: process.env.CHAT_ENCRYPTION_KEY_VERSION
      ? Number(process.env.CHAT_ENCRYPTION_KEY_VERSION)
      : undefined,
    CHAT_ENCRYPTION_PREVIOUS_KEYS: process.env.CHAT_ENCRYPTION_PREVIOUS_KEYS,
  })!;
  const db = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }),
  });
  let encrypted = 0;
  let rotated = 0;
  try {
    for (;;) {
      const rows = await db.chatMessage.findMany({
        where: {
          ...(threadId ? { threadId } : {}),
          OR: [
            { bodyCiphertext: null },
            { keyVersion: { not: cipher.version } },
          ],
        },
        take: 500,
        orderBy: { createdAt: 'asc' },
      });
      if (rows.length === 0) break;
      for (const row of rows) {
        const aad = chatAad(row.id, row.threadId);
        const plain = row.bodyCiphertext
          ? cipher.decrypt({ ciphertext: row.bodyCiphertext, keyVersion: row.keyVersion! }, aad)
          : (row.body ?? '');
        if (row.bodyCiphertext) rotated += 1;
        else encrypted += 1;
        if (dryRun) continue;
        const sealed = cipher.encrypt(plain, aad);
        await db.chatMessage.update({
          where: { id: row.id },
          data: { body: null, bodyCiphertext: sealed.ciphertext, keyVersion: sealed.keyVersion },
        });
      }
      if (dryRun) break;
    }
    console.log(JSON.stringify({ dryRun, encrypted, rotated, keyVersion: cipher.version }));
  } finally {
    await db.$disconnect();
  }
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : 'backfill failed');
  process.exit(1);
});
