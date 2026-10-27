import { createHmac } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import {
  VOICE_SESSION_TTL_SECONDS,
  type VoiceAggregateType,
} from './voice.constants.js';

export type CreateVoiceSessionInput = {
  aggregateType: VoiceAggregateType;
  aggregateId: string;
  userId: string;
};

export type VoiceSessionView = {
  roomName: string;
  token: string;
  url: string;
  expiresAt: string;
  /** Audio-only baseline (DEC-PROD-007): no video, no recording. */
  audioOnly: true;
};

export interface VoicePort {
  /** False when no provider is configured: the call API answers VOICE_UNAVAILABLE. */
  readonly available: boolean;
  createSession(input: CreateVoiceSessionInput): Promise<VoiceSessionView>;
}

export class UnavailableVoiceError extends Error {
  constructor(message = 'Voice provider is not configured') {
    super(message);
    this.name = 'UnavailableVoiceError';
  }
}

@Injectable()
export class UnavailableVoicePort implements VoicePort {
  readonly available = false;

  async createSession(): Promise<VoiceSessionView> {
    throw new UnavailableVoiceError();
  }
}

/**
 * Deterministic mock for non-production. Production boot refuses VOICE_PROVIDER=mock.
 */
@Injectable()
export class MockVoicePort implements VoicePort {
  readonly available = true;

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async createSession(input: CreateVoiceSessionInput): Promise<VoiceSessionView> {
    if (this.nodeEnv === 'production') {
      throw new UnavailableVoiceError('Voice mock is not available in production');
    }
    const roomName = roomNameFor(input.aggregateType, input.aggregateId);
    const expiresAt = new Date(Date.now() + VOICE_SESSION_TTL_SECONDS * 1000);
    const token = `mock.${Buffer.from(
      JSON.stringify({
        room: roomName,
        sub: input.userId,
        exp: Math.floor(expiresAt.getTime() / 1000),
        video: false,
        audio: true,
      }),
    ).toString('base64url')}`;
    return {
      roomName,
      token,
      url: 'wss://mock.livekit.local',
      expiresAt: expiresAt.toISOString(),
      audioOnly: true,
    };
  }
}

export type LiveKitCredentials = {
  url: string;
  apiKey: string;
  apiSecret: string;
};

/**
 * Signs a LiveKit access token (HS256 JWT) with audio-only grants.
 * Does not call LiveKit HTTP APIs — clients join with the returned URL + token.
 */
@Injectable()
export class LiveKitVoicePort implements VoicePort {
  readonly available = true;

  constructor(private readonly credentials: LiveKitCredentials) {}

  async createSession(input: CreateVoiceSessionInput): Promise<VoiceSessionView> {
    const roomName = roomNameFor(input.aggregateType, input.aggregateId);
    const nowSeconds = Math.floor(Date.now() / 1000);
    const exp = nowSeconds + VOICE_SESSION_TTL_SECONDS;
    const token = signLiveKitToken({
      apiKey: this.credentials.apiKey,
      apiSecret: this.credentials.apiSecret,
      identity: input.userId,
      roomName,
      nbf: nowSeconds,
      exp,
    });
    return {
      roomName,
      token,
      url: this.credentials.url,
      expiresAt: new Date(exp * 1000).toISOString(),
      audioOnly: true,
    };
  }
}

export function roomNameFor(aggregateType: VoiceAggregateType, aggregateId: string): string {
  const prefix = aggregateType === 'Ride' ? 'ride' : 'food';
  return `dealgo-${prefix}-${aggregateId}`;
}

export function signLiveKitToken(input: {
  apiKey: string;
  apiSecret: string;
  identity: string;
  roomName: string;
  nbf: number;
  exp: number;
}): string {
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = base64url(
    JSON.stringify({
      iss: input.apiKey,
      sub: input.identity,
      nbf: input.nbf,
      exp: input.exp,
      video: {
        roomJoin: true,
        room: input.roomName,
        canPublish: true,
        canSubscribe: true,
        canPublishData: false,
        // Audio-only: deny video publish/subscribe at grant level.
        canPublishSources: ['microphone'],
      },
      metadata: JSON.stringify({ audioOnly: true }),
    }),
  );
  const unsigned = `${header}.${payload}`;
  const signature = createHmac('sha256', input.apiSecret)
    .update(unsigned)
    .digest('base64url');
  return `${unsigned}.${signature}`;
}

function base64url(value: string): string {
  return Buffer.from(value).toString('base64url');
}
