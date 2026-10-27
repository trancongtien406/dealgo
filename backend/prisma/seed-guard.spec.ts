import { describe, expect, it, vi } from 'vitest';
import { assertSeedAllowed, resolveSeedPassword } from './seed-guard.js';

describe('seed guard', () => {
  it('refuses production unless explicitly overridden', () => {
    expect(() => assertSeedAllowed({ NODE_ENV: 'production' })).toThrow(/refuses/);
    expect(() =>
      assertSeedAllowed({ NODE_ENV: 'production', SEED_ALLOW_PRODUCTION: 'true' }),
    ).not.toThrow();
    expect(() => assertSeedAllowed({ NODE_ENV: 'development' })).not.toThrow();
  });

  it('uses the env password and never a hardcoded fallback', () => {
    expect(resolveSeedPassword({ SEED_USER_PASSWORD: ' a1 ' })).toBe('a1');
    expect(resolveSeedPassword({ OPS_BOOTSTRAP_PASSWORD: 'b2' })).toBe('b2');
    expect(() => resolveSeedPassword({ NODE_ENV: 'production' })).toThrow(/requires/);
  });

  it('generates a random dev password and announces it once', () => {
    const announce = vi.fn();
    const first = resolveSeedPassword({ NODE_ENV: 'development' }, announce);
    const second = resolveSeedPassword({ NODE_ENV: 'development' }, () => undefined);
    expect(first).toHaveLength(24);
    expect(first).not.toBe(second);
    expect(first).not.toBe('change-me-dev-only');
    expect(announce).toHaveBeenCalledTimes(1);
  });
});
