import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig } from 'prisma/config';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@localhost:5432/dealgo?schema=public';

// `env("DATABASE_URL")` throws when the variable is unset, which blocks
// `prisma generate` on a machine with no database. Generate does not connect.
function databaseUrl(): string {
  const fromProcess = process.env.DATABASE_URL?.trim();
  if (fromProcess) {
    return fromProcess;
  }

  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) {
    return LOCAL_DATABASE_URL;
  }

  const line = readFileSync(envFile, 'utf8')
    .split('\n')
    .find((entry) => entry.startsWith('DATABASE_URL='));
  if (!line) {
    return LOCAL_DATABASE_URL;
  }

  const value = line
    .slice('DATABASE_URL='.length)
    .trim()
    .replace(/^['"]|['"]$/g, '');
  return value || LOCAL_DATABASE_URL;
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    url: databaseUrl(),
  },
});
