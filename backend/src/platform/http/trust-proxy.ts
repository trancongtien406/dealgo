/**
 * DEC-PROD-053: Express "trust proxy" from TRUST_PROXY so req.ip (used by ThrottlerGuard and the
 * account-settings audit) is the real client address behind a load balancer / reverse proxy.
 *
 * - unset / "" / "false" / "0" → undefined (do not trust X-Forwarded-For; req.ip = socket peer)
 * - "true"                      → true (trust every hop; only when the proxy strips client XFF)
 * - "1", "2", …                 → hop count (recommended: 1 behind one LB / nginx)
 * - anything else               → CSV of trusted addresses/subnets or "loopback", "uniquelocal" …
 */
export type TrustProxySetting = boolean | number | string[];

export function parseTrustProxy(raw: string | undefined | null): TrustProxySetting | undefined {
  const value = raw?.trim() ?? '';
  if (value === '' || value === 'false' || value === '0') return undefined;
  if (value === 'true') return true;
  if (/^\d+$/.test(value)) return Number(value);
  const list = value
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
  return list.length > 0 ? list : undefined;
}

type ExpressLike = { set(setting: string, value: unknown): unknown };

/** Applies TRUST_PROXY to an Express instance; returns the applied value (undefined = untouched). */
export function applyTrustProxy(
  app: ExpressLike,
  raw: string | undefined | null,
): TrustProxySetting | undefined {
  const setting = parseTrustProxy(raw);
  if (setting !== undefined) app.set('trust proxy', setting);
  return setting;
}
