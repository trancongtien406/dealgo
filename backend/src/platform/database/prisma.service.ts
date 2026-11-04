import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../generated/prisma/client.js';
import type { AppEnv } from '../config/env.js';
import type { DatabasePing } from './database-ping.js';

const PING_TIMEOUT_MS = 1000;

@Injectable()
export class PrismaService implements DatabasePing, OnModuleDestroy {
  private client: PrismaClient | null = null;

  constructor(private readonly config: ConfigService<AppEnv, true>) {}

  async ping(): Promise<boolean> {
    const databaseUrl = this.config.get('DATABASE_URL', { infer: true });
    if (!databaseUrl) {
      return false;
    }

    try {
      const client = this.open(databaseUrl);
      await withTimeout(client.$queryRaw`SELECT 1`, PING_TIMEOUT_MS);
      return true;
    } catch {
      return false;
    }
  }

  db(): PrismaClient | null {
    const databaseUrl = this.config.get('DATABASE_URL', { infer: true });
    if (!databaseUrl) {
      return null;
    }
    return this.open(databaseUrl);
  }

  async onModuleDestroy(): Promise<void> {
    await this.client?.$disconnect();
    this.client = null;
  }

  private open(databaseUrl: string): PrismaClient {
    if (this.client) {
      return this.client;
    }

    const adapter = new PrismaPg(
      {
        connectionString: databaseUrl,
        // Applies to the whole pool, so this is a request budget, not a
        // health-check budget: the 1 s ping timeout would fail ordinary
        // queries whenever the pool is briefly saturated.
        connectionTimeoutMillis: this.config.get(
          'DATABASE_CONNECT_TIMEOUT_MS',
          { infer: true },
        ),
        // Per process: API and worker each open their own pool.
        max: this.config.get('DATABASE_POOL_MAX', { infer: true }),
      },
      {
        // An idle pg client emits 'error'. Without a listener Node crashes the process.
        onPoolError: () => undefined,
      },
    );
    this.client = new PrismaClient({ adapter });
    return this.client;
  }
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timer);
        reject(error instanceof Error ? error : new Error('query failed'));
      },
    );
  });
}
