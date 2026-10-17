import { createSign, createPrivateKey } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import type { PushNotification, PushSender } from './push-sender.js';

export type FcmCredentials = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
};

export type PushTokenLookup = (userId: string) => Promise<string[]>;

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
  private cachedAccessToken: { value: string; expiresAtMs: number } | null = null;

  constructor(
    private readonly credentials: FcmCredentials,
    private readonly tokensForUser: PushTokenLookup = async () => [],
    private readonly fetchFn: FetchLike = fetch,
  ) {}

  async send(notification: PushNotification): Promise<void> {
    const tokens = await this.tokensForUser(notification.userId);
    if (tokens.length === 0) {
      this.logger.debug(
        `FCM skipped: no device tokens for user=${redactUserId(notification.userId)}`,
      );
      return;
    }
    const accessToken = await this.getAccessToken();
    for (const token of tokens) {
      await this.sendToToken(accessToken, token, notification);
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
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data,
        },
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      const detail = await safeText(response);
      throw new Error(`FCM HTTP ${response.status}${detail ? `: ${detail}` : ''}`);
    }
  }

  private async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedAccessToken && this.cachedAccessToken.expiresAtMs > now + 60_000) {
      return this.cachedAccessToken.value;
    }
    const assertion = signServiceAccountJwt(this.credentials, Math.floor(now / 1000));
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
      throw new Error(`FCM OAuth token exchange failed HTTP ${response.status}`);
    }
    const json = (await response.json()) as { access_token?: unknown; expires_in?: unknown };
    if (typeof json.access_token !== 'string' || json.access_token.length === 0) {
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
  const signature = createSign('RSA-SHA256').update(unsigned).end().sign(key, 'base64url');
  return `${unsigned}.${signature}`;
}

function base64url(value: string): string {
  return Buffer.from(value).toString('base64url');
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
