import { createPrivateKey, sign, type KeyObject } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { connect, type ClientHttp2Session } from 'node:http2';
import { isAbsolute, resolve } from 'node:path';
import { Logger } from '@nestjs/common';

/** Platform label the app registers its PushKit (VoIP) token under. FCM never sees these. */
export const VOIP_PUSH_PLATFORM = 'ios-voip';

export const VOIP_PUSH_SENDER = Symbol('VOIP_PUSH_SENDER');

export type IncomingCallVoipPush = {
  userId: string;
  callId: string;
  /** Shown by CallKit as the caller ("Khách đang gọi cho bạn"). */
  title: string;
  body: string;
  ringSeconds: number;
  data: Record<string, string>;
};

/**
 * Wakes the iOS app with a PushKit push so CallKit rings even when the app was killed.
 * Apple requires the app to report a CallKit call for every VoIP push it receives
 * (AppDelegate does), so only incoming-call pushes go through here.
 */
export interface VoipPushSender {
  readonly enabled: boolean;
  /** Resolves with how many devices APNs accepted the VoIP push for (0 = none rang). */
  sendIncomingCall(push: IncomingCallVoipPush): Promise<number>;
}

export class DisabledVoipPushSender implements VoipPushSender {
  readonly enabled = false;
  async sendIncomingCall(): Promise<number> {
    return 0;
  }
}

export type ApnsVoipConfig = {
  keyId: string;
  teamId: string;
  /** PEM of the APNs auth key (.p8). */
  privateKey: string;
  /** App bundle id; the VoIP topic is `<bundleId>.voip`. */
  bundleId: string;
  sandbox: boolean;
};

export type ApnsVoipEnv = {
  APNS_KEY_ID?: string;
  APNS_TEAM_ID?: string;
  /** .p8 PEM pasted into env (`\n` escapes allowed). */
  APNS_PRIVATE_KEY?: string;
  /** Path to the .p8 file (relative paths resolve from process.cwd()). */
  APNS_KEY_PATH?: string;
  /** Older name of APNS_KEY_PATH, still read. */
  APNS_PRIVATE_KEY_PATH?: string;
  APNS_BUNDLE_ID?: string;
  /** `sandbox` | `production`; wins over APNS_SANDBOX. */
  APNS_ENV?: string;
  APNS_SANDBOX?: boolean;
  NODE_ENV?: string;
};

export const APNS_DEFAULT_BUNDLE_ID = 'com.nguyenngoctien.dealgo';
export const APNS_SANDBOX_ORIGIN = 'https://api.sandbox.push.apple.com';
export const APNS_PRODUCTION_ORIGIN = 'https://api.push.apple.com';

/**
 * Why VoIP pushes are off: `missing` = nothing configured (fine, calls ring via the FCM
 * alert); the rest mean the owner started configuring APNs and something is wrong.
 */
export type ApnsVoipDisabledReason =
  'missing' | 'partial' | 'unreadable-key' | 'invalid-key' | 'invalid-env';

export type ApnsVoipStatus =
  | { config: ApnsVoipConfig; reason?: undefined; detail?: undefined }
  | { config: null; reason: ApnsVoipDisabledReason; detail: string };

/** APNs host for the resolved environment. */
export function apnsOrigin(config: Pick<ApnsVoipConfig, 'sandbox'>): string {
  return config.sandbox ? APNS_SANDBOX_ORIGIN : APNS_PRODUCTION_ORIGIN;
}

/**
 * Sandbox vs production: APNS_ENV, else APNS_SANDBOX, else NODE_ENV (production servers
 * talk to the production host, which is what TestFlight / App Store builds use).
 */
export function apnsSandboxFrom(
  env: Pick<ApnsVoipEnv, 'APNS_ENV' | 'APNS_SANDBOX' | 'NODE_ENV'>,
): boolean | null {
  const named = env.APNS_ENV?.trim().toLowerCase();
  if (named) {
    if (named === 'sandbox' || named === 'development') {
      return true;
    }
    if (named === 'production') {
      return false;
    }
    return null;
  }
  if (env.APNS_SANDBOX !== undefined) {
    return env.APNS_SANDBOX;
  }
  return env.NODE_ENV !== 'production';
}

/** Resolves the APNs token-auth config, or why VoIP pushes stay off. Never echoes the key. */
export function apnsVoipStatusFrom(env: ApnsVoipEnv): ApnsVoipStatus {
  const keyId = env.APNS_KEY_ID?.trim();
  const teamId = env.APNS_TEAM_ID?.trim();
  const inlineKey = env.APNS_PRIVATE_KEY?.replace(/\\n/g, '\n').trim();
  const keyPath =
    (env.APNS_KEY_PATH?.trim() || env.APNS_PRIVATE_KEY_PATH?.trim()) ?? '';
  const hasKey = Boolean(inlineKey || keyPath);
  if (!keyId && !teamId && !hasKey) {
    return {
      config: null,
      reason: 'missing',
      detail: 'APNS_KEY_ID, APNS_TEAM_ID and APNS_KEY_PATH are not set',
    };
  }
  if (!hasKey) {
    // Key id / team id are non-secret and may sit prefilled in .env before the .p8 is placed.
    return {
      config: null,
      reason: 'missing',
      detail: 'APNS_KEY_PATH (or APNS_PRIVATE_KEY) is not set',
    };
  }
  const absent = [!keyId && 'APNS_KEY_ID', !teamId && 'APNS_TEAM_ID'].filter(
    Boolean,
  );
  if (absent.length > 0) {
    return {
      config: null,
      reason: 'partial',
      detail: `${absent.join(' and ')} not set`,
    };
  }
  const sandbox = apnsSandboxFrom(env);
  if (sandbox === null) {
    return {
      config: null,
      reason: 'invalid-env',
      detail: 'APNS_ENV must be sandbox or production',
    };
  }
  let privateKey = inlineKey;
  if (!privateKey) {
    const absolute = isAbsolute(keyPath)
      ? keyPath
      : resolve(process.cwd(), keyPath);
    try {
      privateKey = existsSync(absolute)
        ? readFileSync(absolute, 'utf8').trim()
        : undefined;
    } catch {
      privateKey = undefined;
    }
    if (!privateKey) {
      return {
        config: null,
        reason: 'unreadable-key',
        detail: `APNs key file not readable at ${absolute}`,
      };
    }
  }
  try {
    createPrivateKey(privateKey);
  } catch {
    return {
      config: null,
      reason: 'invalid-key',
      detail: 'APNs key is not a valid .p8 (PKCS#8 PEM) private key',
    };
  }
  return {
    config: {
      keyId: keyId!,
      teamId: teamId!,
      privateKey,
      bundleId: env.APNS_BUNDLE_ID?.trim() || APNS_DEFAULT_BUNDLE_ID,
      sandbox,
    },
  };
}

const APNS_ENV_KEYS = [
  'APNS_KEY_ID',
  'APNS_TEAM_ID',
  'APNS_PRIVATE_KEY',
  'APNS_KEY_PATH',
  'APNS_PRIVATE_KEY_PATH',
  'APNS_BUNDLE_ID',
  'APNS_ENV',
  'APNS_SANDBOX',
  'NODE_ENV',
] as const satisfies readonly (keyof ApnsVoipEnv)[];

/** Picks the APNs keys out of any env source (ConfigService.get, parsed AppEnv). */
export function apnsVoipEnvFrom(
  get: (key: (typeof APNS_ENV_KEYS)[number]) => unknown,
): ApnsVoipEnv {
  const env: Record<string, unknown> = {};
  for (const key of APNS_ENV_KEYS) {
    env[key] = get(key);
  }
  return env as ApnsVoipEnv;
}

/** Null (VoIP pushes off) unless key id, team id and a valid .p8 key are all set. */
export function apnsVoipConfigFrom(env: ApnsVoipEnv): ApnsVoipConfig | null {
  return apnsVoipStatusFrom(env).config;
}

export type Http2Request = (
  origin: string,
  path: string,
  headers: Record<string, string>,
  body: string,
) => Promise<{ status: number; body: string }>;

/** APNs HTTP/2 with token (JWT ES256) auth. */
export class ApnsVoipPushSender implements VoipPushSender {
  readonly enabled = true;
  private readonly logger = new Logger(ApnsVoipPushSender.name);
  private readonly key: KeyObject;
  private jwt?: { value: string; issuedAt: number };

  constructor(
    private readonly config: ApnsVoipConfig,
    private readonly tokensFor: (userId: string) => Promise<string[]>,
    private readonly forget: (token: string) => Promise<void>,
    private readonly request: Http2Request = http2Request,
    private readonly now: () => number = Date.now,
  ) {
    this.key = createPrivateKey(config.privateKey);
  }

  async sendIncomingCall(push: IncomingCallVoipPush): Promise<number> {
    const tokens = await this.tokensFor(push.userId);
    if (tokens.length === 0) {
      return 0;
    }
    let delivered = 0;
    const origin = apnsOrigin(this.config);
    const payload = JSON.stringify({
      aps: {},
      ...push.data,
      callId: push.callId,
      title: push.title,
      body: push.body,
      ringSeconds: String(push.ringSeconds),
    });
    const expiration = Math.floor(this.now() / 1000) + push.ringSeconds;
    for (const token of tokens) {
      try {
        const res = await this.request(
          origin,
          `/3/device/${token}`,
          {
            authorization: `bearer ${this.bearer()}`,
            'apns-topic': `${this.config.bundleId}.voip`,
            'apns-push-type': 'voip',
            'apns-priority': '10',
            'apns-expiration': String(expiration),
            'apns-collapse-id': `call-${push.callId}`.slice(0, 64),
          },
          payload,
        );
        if (res.status === 200) {
          this.logger.debug(`VoIP push sent for call ${push.callId.slice(-4)}`);
          delivered += 1;
          continue;
        }
        const reason = safeReason(res.body);
        if (
          res.status === 410 ||
          reason === 'BadDeviceToken' ||
          reason === 'Unregistered'
        ) {
          await this.forget(token);
        }
        this.logger.warn(`VoIP push rejected (${res.status} ${reason ?? ''})`);
      } catch (error) {
        this.logger.warn(`VoIP push failed: ${String(error)}`);
      }
    }
    return delivered;
  }

  /** APNs accepts a provider token for up to an hour; refresh after 50 minutes. */
  private bearer(): string {
    const nowSec = Math.floor(this.now() / 1000);
    if (this.jwt && nowSec - this.jwt.issuedAt < 50 * 60) {
      return this.jwt.value;
    }
    const header = base64url(
      JSON.stringify({ alg: 'ES256', kid: this.config.keyId }),
    );
    const claims = base64url(
      JSON.stringify({ iss: this.config.teamId, iat: nowSec }),
    );
    const signature = sign('sha256', Buffer.from(`${header}.${claims}`), {
      key: this.key,
      dsaEncoding: 'ieee-p1363',
    });
    const value = `${header}.${claims}.${base64url(signature)}`;
    this.jwt = { value, issuedAt: nowSec };
    return value;
  }
}

function base64url(input: string | Buffer): string {
  return Buffer.from(input).toString('base64url');
}

function safeReason(body: string): string | undefined {
  try {
    const parsed = JSON.parse(body) as { reason?: unknown };
    return typeof parsed.reason === 'string' ? parsed.reason : undefined;
  } catch {
    return undefined;
  }
}

const sessions = new Map<string, ClientHttp2Session>();

/** One shared HTTP/2 session per APNs origin, reopened after it closes. */
const http2Request: Http2Request = (origin, path, headers, body) =>
  new Promise((resolvePromise, reject) => {
    let session = sessions.get(origin);
    if (!session || session.closed || session.destroyed) {
      session = connect(origin);
      session.on('error', () => sessions.delete(origin));
      session.on('close', () => sessions.delete(origin));
      session.unref();
      sessions.set(origin, session);
    }
    const req = session.request({
      ':method': 'POST',
      ':path': path,
      ...headers,
    });
    let status = 0;
    let data = '';
    req.setEncoding('utf8');
    req.setTimeout(10_000, () => req.close());
    req.on('response', (h) => {
      status = Number(h[':status'] ?? 0);
    });
    req.on('data', (chunk: string) => {
      data += chunk;
    });
    req.on('end', () => resolvePromise({ status, body: data }));
    // A timed-out or reset stream closes without 'end'; settle it so a call never hangs.
    req.on('close', () => resolvePromise({ status, body: data }));
    req.on('error', reject);
    req.end(body);
  });
