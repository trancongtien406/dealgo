import { createSign, createPrivateKey } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import type { PushNotification, PushSender } from './push-sender.js';
import {
  NEW_JOB_DEFAULT_SOUND_CHANNEL_ID,
  NEW_JOB_SOUNDS,
} from './new-job-sound.js';

export type FcmCredentials = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
};

export type PushTokenLookup = (
  userId: string,
  skipPlatforms?: readonly string[],
) => Promise<string[]>;

/** Called with a token FCM reports as no longer valid, so it can be deleted. */
export type DeadTokenHandler = (token: string) => Promise<void>;

/** FCM v1 answers for a token that will never work again. */
export function isDeadTokenError(status: number, detail: string): boolean {
  return (
    status === 404 ||
    /UNREGISTERED|registration token is not a valid/i.test(detail) ||
    (status === 400 && /INVALID_ARGUMENT/.test(detail) && /token/i.test(detail))
  );
}

class FcmHttpError extends Error {
  constructor(
    readonly status: number,
    readonly detail: string,
  ) {
    super(`FCM HTTP ${status}${detail ? `: ${detail}` : ''}`);
  }
}

type FetchLike = typeof fetch;

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

/**
 * FCM HTTP v1 sender. Uses service-account JWT (RS256) + OAuth token exchange.
 * Without device tokens for the user, send is a no-op (does not throw).
 */
@Injectable()
export class FcmPushSender implements PushSender {
  private readonly logger = new Logger(FcmPushSender.name);
  private cachedAccessToken: { value: string; expiresAtMs: number } | null =
    null;

  constructor(
    private readonly credentials: FcmCredentials,
    private readonly tokensForUser: PushTokenLookup = async () => [],
    private readonly fetchFn: FetchLike = fetch,
    private readonly onDeadToken?: DeadTokenHandler,
  ) {}

  async send(notification: PushNotification): Promise<void> {
    const tokens = await this.tokensForUser(
      notification.userId,
      notification.skipPlatforms,
    );
    if (tokens.length === 0) {
      this.logger.debug(
        `FCM skipped: no device tokens for user=${redactUserId(notification.userId)}`,
      );
      return;
    }
    const accessToken = await this.getAccessToken();
    // Every device gets its try: one stale install must not hide the push from the phone
    // the user holds now. Dead tokens are dropped; only "nothing delivered" is an error.
    let delivered = 0;
    let lastError: unknown = null;
    for (const token of tokens) {
      try {
        await this.sendToToken(accessToken, token, notification);
        delivered += 1;
      } catch (error) {
        if (
          error instanceof FcmHttpError &&
          isDeadTokenError(error.status, error.detail)
        ) {
          this.logger.debug(
            `FCM dropped a dead token for user=${redactUserId(notification.userId)}`,
          );
          await this.onDeadToken?.(token).catch(() => undefined);
          continue;
        }
        lastError = error;
      }
    }
    // Debug only: routing keys (ids/status/path), never tokens or the message body.
    this.logger.debug(
      `FCM sent ${delivered}/${tokens.length} for user=${redactUserId(notification.userId)} title=${JSON.stringify(notification.title)} route=${JSON.stringify(routeKeys(notification.data))}`,
    );
    if (delivered === 0 && lastError) {
      throw lastError;
    }
  }

  private async sendToToken(
    accessToken: string,
    token: string,
    notification: PushNotification,
  ): Promise<void> {
    const url = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.credentials.projectId)}/messages:send`;
    const response = await this.fetchFn(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify({ message: fcmMessage(token, notification) }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      const detail = await safeText(response);
      throw new FcmHttpError(response.status, detail);
    }
  }

  private async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (
      this.cachedAccessToken &&
      this.cachedAccessToken.expiresAtMs > now + 60_000
    ) {
      return this.cachedAccessToken.value;
    }
    const assertion = signServiceAccountJwt(
      this.credentials,
      Math.floor(now / 1000),
    );
    const body = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    });
    const response = await this.fetchFn(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw new Error(
        `FCM OAuth token exchange failed HTTP ${response.status}`,
      );
    }
    const json = (await response.json()) as {
      access_token?: unknown;
      expires_in?: unknown;
    };
    if (
      typeof json.access_token !== 'string' ||
      json.access_token.length === 0
    ) {
      throw new Error('FCM OAuth token exchange returned no access_token');
    }
    const expiresIn =
      typeof json.expires_in === 'number' && Number.isFinite(json.expires_in)
        ? json.expires_in
        : 3600;
    this.cachedAccessToken = {
      value: json.access_token,
      expiresAtMs: now + expiresIn * 1000,
    };
    return json.access_token;
  }
}

/**
 * FCM HTTP v1 message body. iOS always gets `aps.sound` (default, or the spoken new-job file
 * when `alert.customSound`): without it APNs shows the banner silently, so a driver with the app
 * in the background or killed would miss a new job. New-job pushes also pick the Android channel
 * that carries the sound (NEW_JOB_SOUNDS / NEW_JOB_DEFAULT_SOUND_CHANNEL_ID).
 * Delivery hints (priority, TTL, collapse) are only added when the caller sets them.
 */
export function fcmMessage(
  token: string,
  notification: PushNotification,
): Record<string, unknown> {
  const { collapseKey, ttlSeconds, urgent, alert } = notification;
  if (notification.androidDataOnly) {
    return dataOnlyFcmMessage(token, notification);
  }
  const sound = alert?.customSound ? NEW_JOB_SOUNDS[alert.kind] : undefined;
  const message: Record<string, unknown> = {
    token,
    notification: { title: notification.title, body: notification.body },
    // data.alertSound tells the foreground app which spoken file to play (absent = default).
    data: sound
      ? { ...notification.data, alertSound: sound.name }
      : notification.data,
  };
  const apnsPayload = { aps: { sound: sound ? sound.iosSound : 'default' } };
  if (
    collapseKey === undefined &&
    ttlSeconds === undefined &&
    !urgent &&
    !alert
  ) {
    message.apns = { payload: apnsPayload };
    return message;
  }
  const ttl =
    ttlSeconds === undefined ? undefined : Math.max(0, Math.floor(ttlSeconds));
  const androidNotification: Record<string, string> = {
    ...(collapseKey ? { tag: collapseKey } : {}),
    ...(alert
      ? sound
        ? { channel_id: sound.androidChannelId, sound: sound.name }
        : { channel_id: NEW_JOB_DEFAULT_SOUND_CHANNEL_ID, sound: 'default' }
      : {}),
  };
  message.android = {
    ...(urgent ? { priority: 'HIGH' } : {}),
    ...(ttl === undefined ? {} : { ttl: `${ttl}s` }),
    ...(collapseKey ? { collapse_key: collapseKey } : {}),
    ...(Object.keys(androidNotification).length > 0
      ? { notification: androidNotification }
      : {}),
  };
  const headers: Record<string, string> = {};
  if (urgent) headers['apns-priority'] = '10';
  if (collapseKey) headers['apns-collapse-id'] = collapseKey.slice(0, 64);
  if (ttl !== undefined)
    headers['apns-expiration'] = String(Math.floor(Date.now() / 1000) + ttl);
  message.apns = { headers, payload: apnsPayload };
  return message;
}

/**
 * No top-level `notification`: on Android that block makes the system post its own tray
 * notification next to the CallKit/ConnectionService screen. iOS still shows an alert from
 * aps.alert (CallKit rings via PushKit when configured; this is the fallback), web a card.
 */
function dataOnlyFcmMessage(
  token: string,
  notification: PushNotification,
): Record<string, unknown> {
  const { collapseKey, ttlSeconds } = notification;
  const ttl =
    ttlSeconds === undefined ? undefined : Math.max(0, Math.floor(ttlSeconds));
  const headers: Record<string, string> = {
    'apns-priority': '10',
    'apns-push-type': 'alert',
  };
  if (collapseKey) headers['apns-collapse-id'] = collapseKey.slice(0, 64);
  if (ttl !== undefined)
    headers['apns-expiration'] = String(Math.floor(Date.now() / 1000) + ttl);
  return {
    token,
    data: {
      ...notification.data,
      title: notification.title,
      body: notification.body,
    },
    android: {
      priority: 'HIGH',
      ...(ttl === undefined ? {} : { ttl: `${ttl}s` }),
      ...(collapseKey ? { collapse_key: collapseKey } : {}),
    },
    apns: {
      headers,
      payload: {
        aps: {
          alert: { title: notification.title, body: notification.body },
          sound: 'default',
        },
      },
    },
    webpush: {
      notification: { title: notification.title, body: notification.body },
    },
  };
}

export function normalizeFcmPrivateKey(raw: string): string {
  return raw.includes('\\n') ? raw.replace(/\\n/g, '\n') : raw;
}

export function signServiceAccountJwt(
  credentials: FcmCredentials,
  nowSeconds: number,
  ttlSeconds = 3600,
): string {
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64url(
    JSON.stringify({
      iss: credentials.clientEmail,
      sub: credentials.clientEmail,
      aud: TOKEN_URL,
      iat: nowSeconds,
      exp: nowSeconds + ttlSeconds,
      scope: FCM_SCOPE,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const key = createPrivateKey(normalizeFcmPrivateKey(credentials.privateKey));
  const signature = createSign('RSA-SHA256')
    .update(unsigned)
    .end()
    .sign(key, 'base64url');
  return `${unsigned}.${signature}`;
}

function base64url(value: string): string {
  return Buffer.from(value).toString('base64url');
}

const ROUTE_KEYS = [
  'aggregateType',
  'aggregateId',
  'status',
  'eventType',
  'role',
  'path',
  'callId',
  'kind',
];

function routeKeys(
  data: Record<string, string> | undefined,
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const key of ROUTE_KEYS) {
    if (data?.[key] !== undefined) out[key] = data[key]!;
  }
  return out;
}

function redactUserId(userId: string): string {
  if (userId.length <= 8) {
    return '********';
  }
  return `${userId.slice(0, 4)}…${userId.slice(-4)}`;
}

async function safeText(response: Response): Promise<string> {
  try {
    const text = await response.text();
    return text.slice(0, 200);
  } catch {
    return '';
  }
}
