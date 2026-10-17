import { pingRedis } from './redis-ping.js';

describe('pingRedis', () => {
  it('returns false for a URL that is not Redis', async () => {
    await expect(pingRedis('not-a-url')).resolves.toBe(false);
    await expect(pingRedis('http://localhost:6379')).resolves.toBe(false);
  });

  it('returns false when the Redis port refuses the connection', async () => {
    await expect(pingRedis('redis://127.0.0.1:1', 500)).resolves.toBe(false);
  });
});
