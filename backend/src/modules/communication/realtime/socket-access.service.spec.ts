import { describe, expect, it, vi } from 'vitest';
import type { Socket } from 'socket.io';
import { parseSnapshotRoom } from './realtime.constants.js';
import { extractAccessToken, SocketAccessService } from './socket-access.service.js';

describe('SocketAccessService room authz', () => {
  const rideId = '11111111-1111-4111-8111-111111111111';
  const foodId = '22222222-2222-4222-8222-222222222222';

  it('allows subscribe when ride/food canSubscribe returns true', async () => {
    const rides = { canSubscribe: vi.fn().mockResolvedValue(true) };
    const food = { canSubscribe: vi.fn().mockResolvedValue(true) };
    const access = new SocketAccessService(
      {} as never,
      {} as never,
      rides as never,
      food as never,
    );

    const rideRoom = parseSnapshotRoom(`ride:${rideId}`);
    const foodRoom = parseSnapshotRoom(`food:${foodId}`);
    expect(rideRoom).not.toBeNull();
    expect(foodRoom).not.toBeNull();

    await expect(access.canJoinRoom('user-a', rideRoom!)).resolves.toBe(true);
    await expect(access.canJoinRoom('user-a', foodRoom!)).resolves.toBe(true);
    expect(rides.canSubscribe).toHaveBeenCalledWith('user-a', rideId);
    expect(food.canSubscribe).toHaveBeenCalledWith('user-a', foodId);
  });

  it('denies subscribe when actor is not a participant', async () => {
    const rides = { canSubscribe: vi.fn().mockResolvedValue(false) };
    const food = { canSubscribe: vi.fn().mockResolvedValue(false) };
    const access = new SocketAccessService(
      {} as never,
      {} as never,
      rides as never,
      food as never,
    );

    await expect(
      access.canJoinRoom('stranger', parseSnapshotRoom(`ride:${rideId}`)!),
    ).resolves.toBe(false);
    await expect(
      access.canJoinRoom('stranger', parseSnapshotRoom(`food:${foodId}`)!),
    ).resolves.toBe(false);
  });

  it('reads Bearer from handshake auth.token or Authorization header', () => {
    const viaAuth = {
      handshake: {
        auth: { token: 'Bearer abc.def' },
        headers: {},
      },
    } as unknown as Socket;
    expect(extractAccessToken(viaAuth)).toBe('abc.def');

    const viaHeader = {
      handshake: {
        auth: {},
        headers: { authorization: 'Bearer xyz.token' },
      },
    } as unknown as Socket;
    expect(extractAccessToken(viaHeader)).toBe('xyz.token');

    const missing = {
      handshake: { auth: {}, headers: {} },
    } as unknown as Socket;
    expect(extractAccessToken(missing)).toBeNull();
  });
});
