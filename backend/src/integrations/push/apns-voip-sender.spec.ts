import { generateKeyPairSync, verify } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import {
  ApnsVoipPushSender,
  apnsOrigin,
  apnsSandboxFrom,
  apnsVoipConfigFrom,
  apnsVoipEnvFrom,
  apnsVoipStatusFrom,
  type Http2Request,
} from './apns-voip-sender.js';

const { privateKey, publicKey } = generateKeyPairSync('ec', {
  namedCurve: 'P-256',
});
const pem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();

const push = {
  userId: 'user-1',
  callId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  title: 'Khách đang gọi cho bạn',
  body: 'Chuyến #ABCD: chạm để nghe máy.',
  ringSeconds: 40,
  data: {
    eventType: 'Call.incoming',
    callId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    role: 'DRIVER',
  },
};

describe('apnsVoipConfigFrom', () => {
  it('stays off until key id, team id and key are all set', () => {
    expect(apnsVoipConfigFrom({})).toBeNull();
    expect(
      apnsVoipConfigFrom({ APNS_KEY_ID: 'K', APNS_TEAM_ID: 'T' }),
    ).toBeNull();
    expect(
      apnsVoipConfigFrom({
        APNS_KEY_ID: 'K',
        APNS_TEAM_ID: 'T',
        APNS_PRIVATE_KEY: pem,
      }),
    ).toMatchObject({
      keyId: 'K',
      teamId: 'T',
      bundleId: 'com.trancongtien.dealgo',
      sandbox: true,
    });
  });
});

describe('apnsVoipStatusFrom', () => {
  const ids = { APNS_KEY_ID: 'TL36K38ZKR', APNS_TEAM_ID: '6J3522877H' };

  it('is a clean "missing" no-op when nothing or only the non-secret ids are set', () => {
    expect(apnsVoipStatusFrom({})).toMatchObject({
      config: null,
      reason: 'missing',
    });
    expect(apnsVoipStatusFrom({ ...ids, APNS_KEY_PATH: '  ' })).toMatchObject({
      config: null,
      reason: 'missing',
      detail: expect.stringContaining('APNS_KEY_PATH'),
    });
  });

  it('reads the .p8 from APNS_KEY_PATH (or the older APNS_PRIVATE_KEY_PATH)', () => {
    const dir = mkdtempSync(join(tmpdir(), 'apns-'));
    try {
      const file = join(dir, 'AuthKey_TL36K38ZKR.p8');
      writeFileSync(file, pem);
      expect(
        apnsVoipStatusFrom({ ...ids, APNS_KEY_PATH: file }).config,
      ).toMatchObject({
        keyId: 'TL36K38ZKR',
        teamId: '6J3522877H',
        privateKey: pem.trim(),
      });
      expect(
        apnsVoipConfigFrom({ ...ids, APNS_PRIVATE_KEY_PATH: file })?.keyId,
      ).toBe('TL36K38ZKR');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('accepts the key pasted with \\n escapes', () => {
    const escaped = pem.replace(/\n/g, '\\n');
    expect(
      apnsVoipStatusFrom({ ...ids, APNS_PRIVATE_KEY: escaped }).config
        ?.privateKey,
    ).toBe(pem.trim());
  });

  it('names what is wrong in a half-done setup without echoing the key', () => {
    expect(
      apnsVoipStatusFrom({ APNS_KEY_ID: 'K', APNS_PRIVATE_KEY: pem }),
    ).toMatchObject({
      reason: 'partial',
      detail: 'APNS_TEAM_ID not set',
    });
    expect(
      apnsVoipStatusFrom({ ...ids, APNS_KEY_PATH: '/nope/AuthKey.p8' }),
    ).toMatchObject({
      reason: 'unreadable-key',
    });
    const bad = apnsVoipStatusFrom({
      ...ids,
      APNS_PRIVATE_KEY: 'secret-looking-garbage',
    });
    expect(bad).toMatchObject({ reason: 'invalid-key' });
    expect(bad.detail).not.toContain('secret-looking-garbage');
    expect(
      apnsVoipStatusFrom({ ...ids, APNS_PRIVATE_KEY: pem, APNS_ENV: 'live' }),
    ).toMatchObject({
      reason: 'invalid-env',
    });
  });

  it('picks sandbox vs production: APNS_ENV, then APNS_SANDBOX, then NODE_ENV', () => {
    expect(apnsSandboxFrom({})).toBe(true);
    expect(apnsSandboxFrom({ NODE_ENV: 'production' })).toBe(false);
    expect(
      apnsSandboxFrom({ NODE_ENV: 'production', APNS_SANDBOX: true }),
    ).toBe(true);
    expect(
      apnsSandboxFrom({ NODE_ENV: 'development', APNS_ENV: 'production' }),
    ).toBe(false);
    expect(
      apnsSandboxFrom({
        NODE_ENV: 'production',
        APNS_SANDBOX: false,
        APNS_ENV: 'Sandbox',
      }),
    ).toBe(true);
    expect(apnsSandboxFrom({ APNS_ENV: 'staging' })).toBeNull();
    expect(apnsOrigin({ sandbox: true })).toBe(
      'https://api.sandbox.push.apple.com',
    );
    expect(apnsOrigin({ sandbox: false })).toBe('https://api.push.apple.com');
  });

  it('reads every APNs key from a config source', () => {
    const seen: string[] = [];
    apnsVoipEnvFrom((key) => {
      seen.push(key);
      return undefined;
    });
    expect(seen).toEqual(
      expect.arrayContaining([
        'APNS_KEY_PATH',
        'APNS_PRIVATE_KEY_PATH',
        'APNS_ENV',
        'NODE_ENV',
      ]),
    );
  });
});

describe('ApnsVoipPushSender', () => {
  const config = {
    keyId: 'KEY1',
    teamId: 'TEAM1',
    privateKey: pem,
    bundleId: 'app.test',
    sandbox: true,
  };

  it('posts a signed voip push per token and forgets dead tokens', async () => {
    const calls: Parameters<Http2Request>[] = [];
    const request: Http2Request = vi.fn(
      async (...args: Parameters<Http2Request>) => {
        calls.push(args);
        return args[1].endsWith('/dead')
          ? { status: 410, body: '{"reason":"Unregistered"}' }
          : { status: 200, body: '' };
      },
    );
    const forget = vi.fn(async () => undefined);
    const sender = new ApnsVoipPushSender(
      config,
      async () => ['live', 'dead'],
      forget,
      request,
      () => 1_700_000_000_000,
    );

    await sender.sendIncomingCall(push);

    expect(calls).toHaveLength(2);
    const [origin, path, headers, body] = calls[0]!;
    expect(origin).toBe('https://api.sandbox.push.apple.com');
    expect(path).toBe('/3/device/live');
    expect(headers).toMatchObject({
      'apns-topic': 'app.test.voip',
      'apns-push-type': 'voip',
      'apns-priority': '10',
      'apns-expiration': String(1_700_000_000 + 40),
    });
    expect(JSON.parse(body)).toMatchObject({
      aps: {},
      callId: push.callId,
      title: push.title,
      ringSeconds: '40',
    });

    const jwt = headers.authorization!.replace('bearer ', '');
    const [h, c, sig] = jwt.split('.');
    expect(JSON.parse(Buffer.from(h!, 'base64url').toString())).toEqual({
      alg: 'ES256',
      kid: 'KEY1',
    });
    expect(JSON.parse(Buffer.from(c!, 'base64url').toString())).toEqual({
      iss: 'TEAM1',
      iat: 1_700_000_000,
    });
    expect(
      verify(
        'sha256',
        Buffer.from(`${h}.${c}`),
        { key: publicKey, dsaEncoding: 'ieee-p1363' },
        Buffer.from(sig!, 'base64url'),
      ),
    ).toBe(true);

    expect(forget).toHaveBeenCalledWith('dead');
    expect(forget).toHaveBeenCalledTimes(1);
  });

  it('does nothing without VoIP tokens and survives transport errors', async () => {
    const request = vi.fn(async () => {
      throw new Error('boom');
    });
    const none = new ApnsVoipPushSender(
      config,
      async () => [],
      async () => undefined,
      request,
    );
    await none.sendIncomingCall(push);
    expect(request).not.toHaveBeenCalled();

    const failing = new ApnsVoipPushSender(
      config,
      async () => ['t1'],
      async () => undefined,
      request,
    );
    await expect(failing.sendIncomingCall(push)).resolves.toBe(0);
  });

  it('uses the production host for a production config and keeps tokens on other errors', async () => {
    const origins: string[] = [];
    const forget = vi.fn(async () => undefined);
    const request: Http2Request = vi.fn(async (origin: string) => {
      origins.push(origin);
      return { status: 400, body: '{"reason":"TopicDisallowed"}' };
    });
    const sender = new ApnsVoipPushSender(
      { ...config, sandbox: false },
      async () => ['t1'],
      forget,
      request,
    );
    await expect(sender.sendIncomingCall(push)).resolves.toBe(0);
    expect(origins).toEqual(['https://api.push.apple.com']);
    expect(forget).not.toHaveBeenCalled();
  });
});
