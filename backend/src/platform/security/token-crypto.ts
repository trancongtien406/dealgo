import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { DEV_JWT_ACCESS_SECRET, type AppEnv } from '../config/env.js';

export type SessionChannelName = 'customer' | 'ops';

export type AccessTokenClaims = {
  sub: string;
  sid: string;
  ch: SessionChannelName;
  iat: number;
  exp: number;
};

export function randomOtpCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export function randomSecret(): string {
  return randomBytes(32).toString('base64url');
}

export function accessSecret(env: Pick<AppEnv, 'JWT_ACCESS_SECRET' | 'NODE_ENV'>): string {
  if (env.JWT_ACCESS_SECRET) {
    return env.JWT_ACCESS_SECRET;
  }
  if (env.NODE_ENV === 'production') {
    throw new Error('JWT_ACCESS_SECRET is required');
  }
  return DEV_JWT_ACCESS_SECRET;
}

export function hashOneTimeSecret(value: string, pepper: string): string {
  return createHmac('sha256', pepper).update(value).digest('base64url');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('base64url');
}

// HMAC outputs are fixed length. Compare them without leaking how many bytes matched.
export function fixedEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  if (leftBytes.length !== rightBytes.length) {
    return false;
  }
  return timingSafeEqual(leftBytes, rightBytes);
}

export function signAccessToken(claims: AccessTokenClaims, secret: string): string {
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64url(JSON.stringify(claims));
  const signature = createHmac('sha256', secret).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

export function verifyAccessToken(token: string, secret: string, nowSeconds = unixSeconds()): AccessTokenClaims | null {
  const parts = token.split('.');
  if (parts.length !== 3) {
    return null;
  }
  const [header, body, signature] = parts;
  if (!header || !body || !signature) {
    return null;
  }

  let headerJson: { alg?: unknown };
  try {
    headerJson = JSON.parse(Buffer.from(header, 'base64url').toString('utf8')) as { alg?: unknown };
  } catch {
    return null;
  }
  if (headerJson.alg !== 'HS256') {
    return null;
  }

  const expected = createHmac('sha256', secret).update(`${header}.${body}`).digest('base64url');
  if (!fixedEqual(signature, expected)) {
    return null;
  }

  let payload: Partial<AccessTokenClaims>;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as Partial<AccessTokenClaims>;
  } catch {
    return null;
  }

  if (typeof payload.sub !== 'string' || typeof payload.sid !== 'string') {
    return null;
  }
  if (payload.ch !== 'customer' && payload.ch !== 'ops') {
    return null;
  }
  if (typeof payload.exp !== 'number' || payload.exp <= nowSeconds) {
    return null;
  }
  if (typeof payload.iat !== 'number') {
    return null;
  }

  return {
    sub: payload.sub,
    sid: payload.sid,
    ch: payload.ch,
    iat: payload.iat,
    exp: payload.exp,
  };
}

export function unixSeconds(date = new Date()): number {
  return Math.floor(date.getTime() / 1000);
}

function base64url(value: string): string {
  return Buffer.from(value).toString('base64url');
}
