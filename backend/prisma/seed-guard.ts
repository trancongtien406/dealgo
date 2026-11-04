import { randomBytes } from 'node:crypto';

type SeedEnv = Readonly<Record<string, string | undefined>>;

/**
 * DEC-PROD-053: the demo seed creates well-known accounts and fixtures, so it refuses
 * NODE_ENV=production unless SEED_ALLOW_PRODUCTION=true is set deliberately for one run.
 */
export function assertSeedAllowed(env: SeedEnv): void {
  if (env.NODE_ENV === 'production' && env.SEED_ALLOW_PRODUCTION?.trim() !== 'true') {
    throw new Error(
      'seed refuses NODE_ENV=production. Set SEED_ALLOW_PRODUCTION=true for a deliberate one-off run.',
    );
  }
}

/**
 * Password for seeded demo users. Never hardcoded: SEED_USER_PASSWORD, else OPS_BOOTSTRAP_PASSWORD.
 * In development with neither set, a random password is generated and reported once via
 * `announce`; production requires one of the env values.
 */
export function resolveSeedPassword(
  env: SeedEnv,
  announce: (message: string) => void = (m) => console.log(m),
): string {
  const fromEnv = env.SEED_USER_PASSWORD?.trim() || env.OPS_BOOTSTRAP_PASSWORD?.trim();
  if (fromEnv) return fromEnv;
  if (env.NODE_ENV === 'production') {
    throw new Error('seed requires SEED_USER_PASSWORD or OPS_BOOTSTRAP_PASSWORD in production');
  }
  const generated = randomBytes(18).toString('base64url');
  announce(
    `[seed] No SEED_USER_PASSWORD/OPS_BOOTSTRAP_PASSWORD set. Generated dev password (shown once): ${generated}`,
  );
  console.log('generated', generated);
  return generated;
}
