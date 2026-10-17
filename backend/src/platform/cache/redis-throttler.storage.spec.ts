import { describe, expect, it } from 'vitest';
import { RedisThrottlerStorage } from './redis-throttler.storage.js';

describe('RedisThrottlerStorage', () => {
  it('falls back to local memory rate limiting and blocks when Redis is unreachable', async () => {
    // Unreachable redis URL
    const storage = new RedisThrottlerStorage('redis://127.0.0.1:65534');

    const key = 'test-ip-1';
    const ttl = 60_000;
    const limit = 3;

    // Hit 1
    const res1 = await storage.increment(key, ttl, limit, 0, 'default');
    expect(res1.totalHits).toBe(1);
    expect(res1.isBlocked).toBe(false);

    // Hit 2
    const res2 = await storage.increment(key, ttl, limit, 0, 'default');
    expect(res2.totalHits).toBe(2);
    expect(res2.isBlocked).toBe(false);

    // Hit 3
    const res3 = await storage.increment(key, ttl, limit, 0, 'default');
    expect(res3.totalHits).toBe(3);
    expect(res3.isBlocked).toBe(false);

    // Hit 4 (exceeds limit 3) -> MUST BE BLOCKED
    const res4 = await storage.increment(key, ttl, limit, 0, 'default');
    expect(res4.totalHits).toBe(4);
    expect(res4.isBlocked).toBe(true);
    expect(res4.timeToBlockExpire).toBeGreaterThan(0);

    await storage.onModuleDestroy();
  });
});
