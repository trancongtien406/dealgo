import { generateKeyPairSync } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { FcmPushSender, signServiceAccountJwt } from './fcm-push-sender.js';

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const PEM = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

const CREDENTIALS = {
  projectId: 'dealgo-test',
  clientEmail: 'firebase-adminsdk@dealgo-test.iam.gserviceaccount.com',
  privateKey: PEM,
};

describe('FcmPushSender', () => {
  it('signs a service-account JWT with RS256', () => {
    const jwt = signServiceAccountJwt(CREDENTIALS, 1_700_000_000);
    const [header, payload, signature] = jwt.split('.');
    expect(header).toBeTruthy();
    expect(payload).toBeTruthy();
    expect(signature).toBeTruthy();
    const decoded = JSON.parse(Buffer.from(payload!, 'base64url').toString('utf8')) as {
      iss: string;
      scope: string;
    };
    expect(decoded.iss).toBe(CREDENTIALS.clientEmail);
    expect(decoded.scope).toContain('firebase.messaging');
  });

  it('exchanges OAuth then posts FCM HTTP v1 with mocked fetch', async () => {
    const fetchFn = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url =
        typeof input === 'string'
          ? input
          : input instanceof URL
            ? input.toString()
            : (input as Request).url;
      if (url.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'ya29.test', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      if (url.includes('fcm.googleapis.com/v1/projects/dealgo-test/messages:send')) {
        expect(init?.method).toBe('POST');
        expect(init?.headers).toMatchObject({
          Authorization: 'Bearer ya29.test',
        });
        const rawBody = typeof init?.body === 'string' ? init.body : '';
        const body = JSON.parse(rawBody) as {
          message: { token: string; notification: { title: string } };
        };
        expect(body.message.token).toBe('device-token-1');
        expect(body.message.notification.title).toBe('Ride update');
        return new Response('{}', { status: 200 });
      }
      throw new Error(`Unexpected fetch ${url}`);
    });

    const sender = new FcmPushSender(
      CREDENTIALS,
      async (userId) => (userId === 'user-1' ? ['device-token-1'] : []),
      fetchFn as unknown as typeof fetch,
    );

    await sender.send({
      userId: 'user-1',
      title: 'Ride update',
      body: 'Status changed',
      data: { aggregateType: 'Ride', status: 'ASSIGNED' },
    });

    expect(fetchFn).toHaveBeenCalledTimes(2);
  });

  it('skips FCM when user has no device tokens', async () => {
    const fetchFn = vi.fn();
    const sender = new FcmPushSender(CREDENTIALS, async () => [], fetchFn as unknown as typeof fetch);
    await sender.send({
      userId: 'user-2',
      title: 't',
      body: 'b',
      data: {},
    });
    expect(fetchFn).not.toHaveBeenCalled();
  });
});
