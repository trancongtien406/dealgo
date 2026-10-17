import { describe, expect, it, vi } from 'vitest';
import { SnapshotGateway } from './snapshot.gateway.js';
import type { SnapshotFanoutService } from './snapshot-fanout.service.js';
import type { SocketAccessService } from './socket-access.service.js';

describe('SnapshotGateway subscribe authz', () => {
  const rideId = '11111111-1111-4111-8111-111111111111';

  function gateway(access: Partial<SocketAccessService>) {
    const fanout = { bindServer: vi.fn() } as unknown as SnapshotFanoutService;
    const config = {
      get: vi.fn((key: string) => {
        if (key === 'REDIS_URL') {
          return undefined;
        }
        if (key === 'NODE_ENV') {
          return 'test';
        }
        return undefined;
      }),
    };
    const accessWithDefaults = {
      verifyActiveActor: vi.fn().mockResolvedValue(true),
      ...access,
    };
    return new SnapshotGateway(accessWithDefaults as SocketAccessService, fanout, config as never);
  }

  function client(userId = 'user-a') {
    return {
      data: { actor: { userId, sessionId: 's1', channel: 'customer' } },
      join: vi.fn().mockResolvedValue(undefined),
      leave: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
      disconnect: vi.fn(),
    };
  }

  it('denies join when canJoinRoom is false', async () => {
    const access = { canJoinRoom: vi.fn().mockResolvedValue(false) };
    const gw = gateway(access);
    const sock = client('stranger');

    await expect(
      gw.subscribe(sock as never, { room: `ride:${rideId}` }),
    ).resolves.toEqual({ ok: false, code: 'FORBIDDEN' });
    expect(sock.join).not.toHaveBeenCalled();
  });

  it('allows join and joins socket room when participant', async () => {
    const access = { canJoinRoom: vi.fn().mockResolvedValue(true) };
    const gw = gateway(access);
    const sock = client('customer-1');

    await expect(
      gw.subscribe(sock as never, { room: `ride:${rideId}` }),
    ).resolves.toEqual({ ok: true, room: `ride:${rideId}` });
    expect(sock.join).toHaveBeenCalledWith(`ride:${rideId}`);
  });

  it('denies subscribe and disconnects socket if session is revoked or expired', async () => {
    const access = {
      verifyActiveActor: vi.fn().mockResolvedValue(false),
      canJoinRoom: vi.fn().mockResolvedValue(true),
    };
    const gw = gateway(access);
    const sock = client('revoked-user');

    await expect(
      gw.subscribe(sock as never, { room: `ride:${rideId}` }),
    ).resolves.toEqual({ ok: false, code: 'UNAUTHORIZED' });
    expect(sock.emit).toHaveBeenCalledWith('error', expect.objectContaining({ code: 'UNAUTHORIZED' }));
    expect(sock.disconnect).toHaveBeenCalledWith(true);
    expect(sock.join).not.toHaveBeenCalled();
  });
});
