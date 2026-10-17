import { ConfigService } from '@nestjs/config';
import { loadEnv, type AppEnv } from '../config/env.js';
import { HealthService } from './health.service.js';
import type { DatabasePing } from '../database/database-ping.js';
import type { RedisProbe } from './redis-ping.js';

function createService(databaseUp: boolean, redisUp: boolean): HealthService {
  const config = new ConfigService<AppEnv, true>(
    loadEnv({
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://dealgo:dealgo_dev@localhost:5432/dealgo',
      REDIS_URL: 'redis://localhost:6379',
    }),
  );
  const database: DatabasePing = { ping: () => Promise.resolve(databaseUp) };
  const redis: RedisProbe = { ping: () => Promise.resolve(redisUp) };
  return new HealthService(config, database, redis);
}

describe('HealthService', () => {
  it('reports ok when database and redis are up', async () => {
    await expect(createService(true, true).check()).resolves.toEqual({
      status: 'ok',
      checks: { database: 'up', redis: 'up' },
    });
  });

  it('reports degraded when a dependency is down', async () => {
    await expect(createService(false, true).check()).resolves.toEqual({
      status: 'degraded',
      checks: { database: 'down', redis: 'up' },
    });
  });

  it('live always reports ok without probing', () => {
    expect(createService(false, false).live()).toEqual({ status: 'ok' });
  });

  it('ready is not_ready when database is down', async () => {
    await expect(createService(false, true).checkReady()).resolves.toEqual({
      status: 'not_ready',
      checks: { database: 'down', redis: 'up' },
    });
  });

  it('ready is degraded when redis is down but database is up in non-prod', async () => {
    await expect(createService(true, false).checkReady()).resolves.toEqual({
      status: 'degraded',
      checks: { database: 'up', redis: 'down' },
    });
  });

  it('ready is not_ready in production when redis is down', async () => {
    const config = new ConfigService<AppEnv, true>(
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'prod-secret-must-be-long-enough',
        SMS_PROVIDER: 'esms',
        PUSH_PROVIDER: 'fcm',
        PAYMENT_PROVIDER: 'vnpay',
        DATABASE_URL: 'postgresql://dealgo:dealgo_dev@localhost:5432/dealgo',
        REDIS_URL: 'redis://localhost:6379',
      }),
    );
    const database: DatabasePing = { ping: () => Promise.resolve(true) };
    const redis: RedisProbe = { ping: () => Promise.resolve(false) };
    const prodHealth = new HealthService(config, database, redis);

    await expect(prodHealth.checkReady()).resolves.toEqual({
      status: 'not_ready',
      checks: { database: 'up', redis: 'down' },
    });
  });
});
