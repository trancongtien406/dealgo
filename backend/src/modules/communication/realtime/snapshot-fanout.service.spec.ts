import { describe, expect, it, vi } from 'vitest';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const room = `ride:${rideId}`;
const snap = (status: string, revision: string) => ({
  eventType: 'RideStatusChanged', aggregateType: 'Ride', aggregateId: rideId, status, revision, occurredAt: 'x',
});

function harness(members: string[], allowed: Set<string>) {
  const order: string[] = [];
  const sockets = members.map((userId) => ({
    data: { actor: { userId } },
    leave: vi.fn(() => order.push(`leave:${userId}`)),
  }));
  const emit = vi.fn((_e: string, p: { status: string }) => order.push(`emit:${p.status}`));
  const server = {
    to: vi.fn().mockReturnValue({ emit }),
    in: vi.fn().mockReturnValue({ fetchSockets: vi.fn().mockResolvedValue(sockets) }),
  };
  const check = vi.fn(async (userId: string) => allowed.has(userId));
  const fanout = new SnapshotFanoutService();
  fanout.bindServer(server as never);
  fanout.bindAccessCheck(check);
  return { fanout, sockets, emit, server, check, order };
}

describe('SnapshotFanoutService ride room pruning', () => {
  it('kicks drivers that lost the selection before emitting ASSIGNED', async () => {
    const h = harness(['customer', 'winner', 'loser'], new Set(['customer', 'winner']));
    h.fanout.emitSnapshot(snap('ASSIGNED', 'r1'));
    await h.fanout.flush();
    expect(h.sockets[2]!.leave).toHaveBeenCalledWith(room);
    expect(h.sockets[0]!.leave).not.toHaveBeenCalled();
    expect(h.sockets[1]!.leave).not.toHaveBeenCalled();
    expect(h.order).toEqual(['leave:loser', 'emit:ASSIGNED']);
  });

  it('kicks sockets without an actor', async () => {
    const h = harness([], new Set());
    (h.server.in as ReturnType<typeof vi.fn>).mockReturnValue({
      fetchSockets: vi.fn().mockResolvedValue([{ data: {}, leave: vi.fn() }]),
    });
    h.fanout.emitSnapshot(snap('IN_TRIP', 'r1'));
    await h.fanout.flush();
    expect(h.check).not.toHaveBeenCalled();
  });

  it('does not re-check while NEGOTIATING (offering drivers stay)', async () => {
    const h = harness(['customer', 'd1'], new Set(['customer']));
    h.fanout.emitSnapshot(snap('NEGOTIATING', 'r0'));
    await h.fanout.flush();
    expect(h.server.in).not.toHaveBeenCalled();
    expect(h.emit).toHaveBeenCalledTimes(1);
  });

  it('keeps snapshot order per room and still emits when pruning fails', async () => {
    const h = harness(['customer'], new Set(['customer']));
    (h.server.in as ReturnType<typeof vi.fn>)
      .mockReturnValueOnce({ fetchSockets: vi.fn().mockRejectedValue(new Error('redis timeout')) })
      .mockReturnValue({ fetchSockets: vi.fn().mockResolvedValue([]) });
    h.fanout.emitSnapshot(snap('ASSIGNED', 'r1'));
    h.fanout.emitSnapshot(snap('DRIVER_EN_ROUTE', 'r2'));
    await h.fanout.flush();
    expect(h.order).toEqual(['emit:ASSIGNED', 'emit:DRIVER_EN_ROUTE']);
  });
});

describe('SnapshotFanoutService call events', () => {
  it('sends the call state to the caller and the callee user rooms only', () => {
    const emit = vi.fn();
    const to = vi.fn(() => ({ emit }));
    const fanout = new SnapshotFanoutService();
    fanout.bindServer({ to } as never);
    const payload = {
      callId: 'c1',
      aggregateType: 'Ride' as const,
      aggregateId: rideId,
      status: 'RINGING' as const,
      callerUserId: 'u-caller',
      calleeUserId: 'u-callee',
      callerRole: 'CUSTOMER' as const,
      ringUntil: 'x',
      endReason: null,
      occurredAt: 'x',
    };
    fanout.emitCall(payload);
    expect(to).toHaveBeenCalledWith(['user:u-caller', 'user:u-callee']);
    expect(emit).toHaveBeenCalledWith('call', payload);
  });
});
