import { generateKeyPairSync } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import {
  FcmPushSender,
  fcmMessage,
  isDeadTokenError,
  signServiceAccountJwt,
} from './fcm-push-sender.js';

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
    const decoded = JSON.parse(
      Buffer.from(payload!, 'base64url').toString('utf8'),
    ) as {
      iss: string;
      scope: string;
    };
    expect(decoded.iss).toBe(CREDENTIALS.clientEmail);
    expect(decoded.scope).toContain('firebase.messaging');
  });

  it('exchanges OAuth then posts FCM HTTP v1 with mocked fetch', async () => {
    const fetchFn = vi.fn(
      async (input: RequestInfo | URL, init?: RequestInit) => {
        const url =
          typeof input === 'string'
            ? input
            : input instanceof URL
              ? input.toString()
              : (input as Request).url;
        if (url.includes('oauth2.googleapis.com/token')) {
          return new Response(
            JSON.stringify({ access_token: 'ya29.test', expires_in: 3600 }),
            {
              status: 200,
              headers: { 'Content-Type': 'application/json' },
            },
          );
        }
        if (
          url.includes(
            'fcm.googleapis.com/v1/projects/dealgo-test/messages:send',
          )
        ) {
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
      },
    );

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
    const sender = new FcmPushSender(
      CREDENTIALS,
      async () => [],
      fetchFn as unknown as typeof fetch,
    );
    await sender.send({
      userId: 'user-2',
      title: 't',
      body: 'b',
      data: {},
    });
    expect(fetchFn).not.toHaveBeenCalled();
  });
});

describe('FcmPushSender with several devices', () => {
  const oauthOr = (handler: (token: string) => Response) =>
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url =
        typeof input === 'string'
          ? input
          : input instanceof URL
            ? input.href
            : input.url;
      if (url.includes('oauth2.googleapis.com/token')) {
        return new Response(
          JSON.stringify({ access_token: 'ya29.test', expires_in: 3600 }),
          { status: 200 },
        );
      }
      const body = JSON.parse(
        typeof init?.body === 'string' ? init.body : '{}',
      ) as { message: { token: string } };
      return handler(body.message.token);
    });
  const note = { userId: 'user-1', title: 't', body: 'b', data: {} };

  it('still reaches the current phone when an old install token is dead, and drops the dead one', async () => {
    const fetchFn = oauthOr((token) =>
      token === 'old'
        ? new Response(
            '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}',
            { status: 404 },
          )
        : new Response('{}', { status: 200 }),
    );
    const dead = vi.fn().mockResolvedValue(undefined);
    const sender = new FcmPushSender(
      CREDENTIALS,
      async () => ['old', 'current'],
      fetchFn as unknown as typeof fetch,
      dead,
    );
    await expect(sender.send(note)).resolves.toBeUndefined();
    expect(fetchFn).toHaveBeenCalledTimes(3);
    expect(dead).toHaveBeenCalledWith('old');
  });

  it('throws only when no device got the push for a transient reason', async () => {
    const fetchFn = oauthOr(() => new Response('busy', { status: 503 }));
    const sender = new FcmPushSender(
      CREDENTIALS,
      async () => ['a', 'b'],
      fetchFn as unknown as typeof fetch,
    );
    await expect(sender.send(note)).rejects.toThrow('FCM HTTP 503');
    expect(fetchFn).toHaveBeenCalledTimes(3);
  });

  it('classifies dead-token answers', () => {
    expect(isDeadTokenError(404, '')).toBe(true);
    expect(
      isDeadTokenError(
        400,
        '{"error":{"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token"}}',
      ),
    ).toBe(true);
    expect(
      isDeadTokenError(
        400,
        '{"error":{"status":"INVALID_ARGUMENT","message":"data must be strings"}}',
      ),
    ).toBe(false);
    expect(isDeadTokenError(503, 'UNAVAILABLE')).toBe(false);
  });
});

describe('fcmMessage', () => {
  const base = { userId: 'u1', title: 't', body: 'b', data: { k: 'v' } };

  it('keeps the plain body plus the iOS default sound when no delivery hints are set', () => {
    expect(fcmMessage('tok', base)).toEqual({
      token: 'tok',
      notification: { title: 't', body: 'b' },
      data: { k: 'v' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

  it('sends an incoming call data-only on Android (no duplicate tray copy) but keeps the iOS/web alert', () => {
    const msg = fcmMessage('tok', {
      ...base,
      data: { eventType: 'Call.incoming', callId: 'c1' },
      collapseKey: 'call-c1',
      ttlSeconds: 40,
      urgent: true,
      androidDataOnly: true,
    }) as Record<string, any>;
    expect(msg.notification).toBeUndefined();
    expect(msg.data).toEqual({
      eventType: 'Call.incoming',
      callId: 'c1',
      title: 't',
      body: 'b',
    });
    expect(msg.android).toEqual({
      priority: 'HIGH',
      ttl: '40s',
      collapse_key: 'call-c1',
    });
    expect(msg.apns.payload.aps).toEqual({
      alert: { title: 't', body: 'b' },
      sound: 'default',
    });
    expect(msg.apns.headers).toMatchObject({
      'apns-priority': '10',
      'apns-push-type': 'alert',
      'apns-collapse-id': 'call-c1',
    });
    expect(msg.webpush).toEqual({ notification: { title: 't', body: 'b' } });
  });

  it('adds collapse, ttl and priority for Android and APNs', () => {
    const msg = fcmMessage('tok', {
      ...base,
      collapseKey: 'ride-request-1',
      ttlSeconds: 90,
      urgent: true,
    }) as {
      android: Record<string, unknown>;
      apns: { headers: Record<string, string>; payload: unknown };
    };
    expect(msg.android).toEqual({
      priority: 'HIGH',
      ttl: '90s',
      collapse_key: 'ride-request-1',
      notification: { tag: 'ride-request-1' },
    });
    expect(msg.apns.headers['apns-priority']).toBe('10');
    expect(msg.apns.headers['apns-collapse-id']).toBe('ride-request-1');
    expect(Number(msg.apns.headers['apns-expiration'])).toBeGreaterThan(
      Date.now() / 1000,
    );
    expect(msg.apns.payload).toEqual({ aps: { sound: 'default' } });
  });

  it('plays the spoken new-job sound: iOS .caf, Android versioned channel + raw sound, data.alertSound', () => {
    const cases = [
      ['NEW_RIDE', 'dealgo_new_ride', 'dealgo_new_ride_v1'],
      ['NEW_FOOD_JOB', 'dealgo_new_food_job', 'dealgo_new_food_job_v1'],
      [
        'MERCHANT_NEW_ORDER',
        'dealgo_merchant_new_order',
        'dealgo_merchant_new_order_v1',
      ],
    ] as const;
    for (const [kind, name, channel] of cases) {
      const msg = fcmMessage('tok', {
        ...base,
        collapseKey: 'ride-request-1',
        urgent: true,
        alert: { kind, customSound: true },
      }) as {
        android: Record<string, unknown>;
        apns: { payload: unknown };
        data: Record<string, string>;
      };
      expect(msg.apns.payload).toEqual({ aps: { sound: `${name}.caf`, 'interruption-level': 'time-sensitive' } });
      expect(msg.android.notification).toEqual({
        tag: 'ride-request-1',
        channel_id: channel,
        sound: name,
      });
      expect(msg.data).toEqual({ k: 'v', alertSound: name });
    }
  });

  it('uses the default sound on the high new-job channel when the custom sound is off', () => {
    const msg = fcmMessage('tok', {
      ...base,
      alert: { kind: 'MERCHANT_NEW_ORDER', customSound: false },
    }) as {
      android: Record<string, unknown>;
      apns: { payload: unknown };
      data: Record<string, string>;
    };
    expect(msg.apns.payload).toEqual({ aps: { sound: 'default', 'interruption-level': 'time-sensitive' } });
    expect(msg.android).toEqual({
      notification: {
        channel_id: 'dealgo_new_job_default_v1',
        sound: 'default',
      },
    });
    expect(msg.data).toEqual({ k: 'v' });
  });
});
