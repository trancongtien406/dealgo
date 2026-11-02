import { afterEach, describe, expect, it, vi } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { PROD_ENV_OK } from '../../../test/fixtures/prod-env.js';
import { loadEnv, type AppEnv } from '../config/env.js';
import { HealthService } from './health.service.js';
import {
  attachRedisSocketAdapter,
  resetRealtimeAdapterState,
} from '../../modules/communication/realtime/redis-io-adapter.js';

vi.mock('redis', () => {
  const client = {
    on: vi.fn(),
    connect: vi.fn().mockRejectedValue(new Error('ECONNREFUSED')),
    isOpen: false,
    quit: vi.fn(),
    destroy: vi.fn(),
  };
  return { createClient: () => ({ ...client, duplicate: () => ({ ...client }) }) };
});

function service(nodeEnv: 'production' | 'test'): HealthService {
  const base = nodeEnv === 'production' ? PROD_ENV_OK : { NODE_ENV: 'test' };
  const config = new ConfigService<AppEnv, true>(
    loadEnv({
      ...base,
      DATABASE_URL: 'postgresql://dealgo:dealgo_dev@localhost:5432/dealgo',
      REDIS_URL: 'redis://localhost:6379',
    }),
  );
  return new HealthService(config, { ping: () => Promise.resolve(true) }, { ping: () => Promise.resolve(true) });
}

describe('realtime adapter fallback readiness (REL-002)', () => {
  afterEach(() => resetRealtimeAdapterState());

  it('is not_ready in production and degraded elsewhere after a fallback', async () => {
    const result = await attachRedisSocketAdapter({ adapter: vi.fn() } as never, 'redis://x:6379', 'production');
    expect(result.mode).toBe('memory');
    await expect(service('production').checkReady()).resolves.toMatchObject({
      status: 'not_ready',
      realtime: 'memory_fallback',
    });
    await expect(service('test').checkReady()).resolves.toMatchObject({
      status: 'degraded',
      realtime: 'memory_fallback',
    });
  });

  it('stays ok without a fallback', async () => {
    await expect(service('production').checkReady()).resolves.toEqual({
      status: 'ok',
      checks: { database: 'up', redis: 'up' },
    });
  });
});
