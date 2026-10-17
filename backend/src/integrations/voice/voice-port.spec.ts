import { describe, expect, it } from 'vitest';
import {
  LiveKitVoicePort,
  MockVoicePort,
  UnavailableVoicePort,
  signLiveKitToken,
} from './voice-port.js';

describe('VoicePort', () => {
  it('mock returns deterministic audio-only session outside production', async () => {
    const port = new MockVoicePort('test');
    const session = await port.createSession({
      aggregateType: 'Ride',
      aggregateId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-1',
    });
    expect(session.audioOnly).toBe(true);
    expect(session.roomName).toBe('dealgo-ride-11111111-1111-1111-1111-111111111111');
    expect(session.token.startsWith('mock.')).toBe(true);
    expect(session.url).toContain('mock.livekit');
  });

  it('mock refuses production', async () => {
    const port = new MockVoicePort('production');
    await expect(
      port.createSession({
        aggregateType: 'FoodOrder',
        aggregateId: '22222222-2222-2222-2222-222222222222',
        userId: 'user-2',
      }),
    ).rejects.toThrow(/production/);
  });

  it('livekit signs HS256 JWT with audio-only grants', async () => {
    const port = new LiveKitVoicePort({
      url: 'wss://dealgo.livekit.cloud',
      apiKey: 'APIKEY',
      apiSecret: 'secret',
    });
    const session = await port.createSession({
      aggregateType: 'FoodOrder',
      aggregateId: '33333333-3333-3333-3333-333333333333',
      userId: 'user-3',
    });
    expect(session.url).toBe('wss://dealgo.livekit.cloud');
    expect(session.audioOnly).toBe(true);
    const parts = session.token.split('.');
    expect(parts).toHaveLength(3);
    const payload = JSON.parse(Buffer.from(parts[1]!, 'base64url').toString('utf8')) as {
      video: { canPublishSources: string[]; room: string };
      metadata: string;
    };
    expect(payload.video.canPublishSources).toEqual(['microphone']);
    expect(payload.video.room).toContain('food');
    expect(JSON.parse(payload.metadata)).toEqual({ audioOnly: true });
  });

  it('signLiveKitToken is stable for fixed claims', () => {
    const a = signLiveKitToken({
      apiKey: 'k',
      apiSecret: 's',
      identity: 'u',
      roomName: 'r',
      nbf: 100,
      exp: 200,
    });
    const b = signLiveKitToken({
      apiKey: 'k',
      apiSecret: 's',
      identity: 'u',
      roomName: 'r',
      nbf: 100,
      exp: 200,
    });
    expect(a).toBe(b);
  });

  it('unavailable fails closed', async () => {
    await expect(new UnavailableVoicePort().createSession()).rejects.toThrow(/not configured/);
  });
});
