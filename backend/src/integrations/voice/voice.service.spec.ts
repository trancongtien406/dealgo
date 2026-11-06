import { HttpException } from '@nestjs/common';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  VOICE_CALL_RING_SECONDS,
  VOICE_MISSED_CALL_NOTE,
} from './voice.constants.js';
import { MemoryVoiceCallRepository } from './voice-call.repository.js';
import {
  MockVoicePort,
  UnavailableVoicePort,
  type VoicePort,
} from './voice-port.js';
import { VoiceService } from './voice.service.js';

const RIDE = '11111111-1111-4111-8111-111111111111';
const ORDER = '22222222-2222-4222-8222-222222222222';
const CUSTOMER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const DRIVER = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const STRANGER = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

const actor = (userId: string) => ({ userId }) as never;

function codeOf(error: unknown): string | undefined {
  if (!(error instanceof HttpException)) return undefined;
  return (error.getResponse() as { errorCode?: string }).errorCode;
}

async function expectCode(
  promise: Promise<unknown>,
  code: string,
): Promise<void> {
  const error = await promise.then(
    () => undefined,
    (e: unknown) => e,
  );
  expect(codeOf(error)).toBe(code);
}

function setup(
  opts: {
    port?: VoicePort;
    enabled?: boolean;
    voip?: boolean;
    voipDelivered?: number;
  } = {},
) {
  const ride = { status: 'IN_PROGRESS', driverId: DRIVER as string | null };
  const order = { status: 'PICKED_UP', driverId: DRIVER as string | null };
  const rides = {
    participantRoles: vi.fn(async () => ({
      customerId: CUSTOMER,
      driverId: ride.driverId,
    })),
    contactMeta: vi.fn(async () => ({
      status: ride.status,
      updatedAt: new Date(),
    })),
  };
  const food = {
    participantRoles: vi.fn(async () => ({
      customerId: CUSTOMER,
      merchantId: 'm',
      driverId: order.driverId,
    })),
    contactMeta: vi.fn(async () => ({
      status: order.status,
      updatedAt: new Date(),
    })),
  };
  const settings = { getBoolean: vi.fn(async () => opts.enabled ?? true) };
  const config = { get: vi.fn(() => 'mock') };
  const fanout = { emitCall: vi.fn() };
  const chat = { recordCallNote: vi.fn(async () => undefined) };
  const push = { send: vi.fn(async () => undefined) };
  const voip = {
    enabled: opts.voip ?? false,
    sendIncomingCall: vi.fn(async () => opts.voipDelivered ?? 0),
  };
  const repo = new MemoryVoiceCallRepository();
  const service = new VoiceService(
    opts.port ?? new MockVoicePort('test'),
    repo,
    rides as never,
    food as never,
    config as never,
    settings as never,
    fanout as never,
    chat as never,
    push as never,
    undefined,
    undefined,
    voip as never,
  );
  return { service, ride, order, fanout, chat, push, repo, settings, voip };
}

describe('VoiceService calls', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('rings the assigned driver and gives the caller an audio-only token for the trip room', async () => {
    const { service, fanout, push } = setup();
    const { call, session } = await service.startForRide(actor(CUSTOMER), RIDE);
    expect(call).toMatchObject({
      status: 'RINGING',
      callerUserId: CUSTOMER,
      calleeUserId: DRIVER,
      callerRole: 'CUSTOMER',
      aggregateType: 'Ride',
    });
    expect(session.roomName).toBe(`dealgo-ride-${RIDE}`);
    expect(session.audioOnly).toBe(true);
    expect(fanout.emitCall).toHaveBeenCalledWith(
      expect.objectContaining({ callId: call.id, status: 'RINGING' }),
    );
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: DRIVER,
        urgent: true,
        androidDataOnly: true,
        collapseKey: `call-${call.id}`,
        data: expect.objectContaining({
          eventType: 'Call.incoming',
          callId: call.id,
          role: 'DRIVER',
        }),
      }),
    );
    service.onModuleDestroy();
  });

  it('sends the iOS PushKit push only when the APNs VoIP sender is configured', async () => {
    const off = setup();
    await off.service.startForRide(actor(CUSTOMER), RIDE);
    expect(off.voip.sendIncomingCall).not.toHaveBeenCalled();
    off.service.onModuleDestroy();

    const on = setup({ voip: true });
    const { call } = await on.service.startForRide(actor(CUSTOMER), RIDE);
    expect(on.voip.sendIncomingCall).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: DRIVER,
        callId: call.id,
        title: 'Khách đang gọi cho bạn',
        data: expect.objectContaining({
          eventType: 'Call.incoming',
          role: 'DRIVER',
        }),
      }),
    );
    on.service.onModuleDestroy();
  });

  it('only lets the customer and the assigned driver call, and only while the trip runs', async () => {
    const { service, ride, order } = setup();
    await expectCode(
      service.startForRide(actor(STRANGER), RIDE),
      'VOICE_FORBIDDEN',
    );
    ride.status = 'COMPLETED';
    await expectCode(
      service.startForRide(actor(CUSTOMER), RIDE),
      'VOICE_WINDOW_CLOSED',
    );
    ride.status = 'NEGOTIATING';
    ride.driverId = null;
    await expectCode(
      service.startForRide(actor(CUSTOMER), RIDE),
      'VOICE_NO_COUNTERPART',
    );
    order.status = 'DELIVERED';
    await expectCode(
      service.startForFood(actor(DRIVER), ORDER),
      'VOICE_WINDOW_CLOSED',
    );
  });

  it('refuses to ring a callee who is already on another call', async () => {
    const { service } = setup();
    // The customer calls the driver on the ride…
    await service.startForRide(actor(CUSTOMER), RIDE);
    // …so the driver cannot also be rung for the food order: one phone, one call screen.
    await expectCode(
      service.startForFood(actor(CUSTOMER), ORDER),
      'VOICE_BUSY',
    );
  });

  it('puts the ring window in the push so the native call screen matches the server', async () => {
    const { service, push } = setup();
    await service.startForRide(actor(CUSTOMER), RIDE);
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          ringSeconds: String(VOICE_CALL_RING_SECONDS),
        }),
      }),
    );
  });

  it('fails closed when the admin toggle is off or no provider is configured', async () => {
    await expectCode(
      setup({ enabled: false }).service.startForRide(actor(CUSTOMER), RIDE),
      'VOICE_DISABLED',
    );
    const off = setup({ port: new UnavailableVoicePort() });
    await expectCode(
      off.service.startForRide(actor(CUSTOMER), RIDE),
      'VOICE_UNAVAILABLE',
    );
    expect(await off.service.callConfig()).toEqual({
      enabled: false,
      ringSeconds: VOICE_CALL_RING_SECONDS,
    });
    expect((await setup().service.callConfig()).enabled).toBe(true);
  });

  it('accepts once for the callee only, then either side can hang up', async () => {
    const { service, fanout } = setup();
    const { call } = await service.startForFood(actor(DRIVER), ORDER);
    await expectCode(service.accept(actor(DRIVER), call.id), 'VOICE_FORBIDDEN');
    await expectCode(
      service.get(actor(STRANGER), call.id),
      'VOICE_CALL_NOT_FOUND',
    );
    const joined = await service.accept(actor(CUSTOMER), call.id);
    expect(joined.call.status).toBe('ACCEPTED');
    expect(joined.session.roomName).toBe(`dealgo-food-${ORDER}`);
    await expectCode(
      service.accept(actor(CUSTOMER), call.id),
      'VOICE_CALL_NOT_RINGING',
    );
    await expectCode(
      service.startForFood(actor(CUSTOMER), ORDER),
      'VOICE_BUSY',
    );
    const ended = await service.end(actor(DRIVER), call.id);
    expect(ended).toMatchObject({ status: 'ENDED', endReason: 'HANGUP' });
    expect(fanout.emitCall.mock.calls.map(([p]) => p.status)).toEqual([
      'RINGING',
      'ACCEPTED',
      'ENDED',
    ]);
  });

  it('CallKit rang through PushKit → the FCM copy skips iOS (one ring)', async () => {
    const rang = setup({ voip: true, voipDelivered: 1 });
    await rang.service.startForRide(actor(DRIVER), RIDE);
    expect(rang.voip.sendIncomingCall).toHaveBeenCalledTimes(1);
    expect(rang.push.send).toHaveBeenCalledWith(
      expect.objectContaining({ userId: CUSTOMER, skipPlatforms: ['ios'] }),
    );
    rang.service.onModuleDestroy();
    const none = setup({ voip: true, voipDelivered: 0 });
    await none.service.startForRide(actor(DRIVER), RIDE);
    expect(none.push.send).toHaveBeenCalledWith(
      expect.not.objectContaining({ skipPlatforms: expect.anything() }),
    );
    none.service.onModuleDestroy();
  });

  it('records a missed call in the chat when nobody answers', async () => {
    const { service, chat, push } = setup();
    const { call } = await service.startForRide(actor(DRIVER), RIDE);
    await vi.advanceTimersByTimeAsync(VOICE_CALL_RING_SECONDS * 1000 + 10);
    const view = await service.get(actor(CUSTOMER), call.id);
    expect(view).toMatchObject({ status: 'MISSED', endReason: 'NO_ANSWER' });
    expect(chat.recordCallNote).toHaveBeenCalledTimes(1);
    expect(chat.recordCallNote).toHaveBeenCalledWith(
      'Ride',
      RIDE,
      DRIVER,
      VOICE_MISSED_CALL_NOTE,
    );
    expect(push.send).toHaveBeenLastCalledWith(
      expect.objectContaining({
        userId: CUSTOMER,
        data: expect.objectContaining({ eventType: 'Call.missed' }),
      }),
    );
    // The trip can be called again once the previous call closed.
    expect(
      (await service.startForRide(actor(CUSTOMER), RIDE)).call.status,
    ).toBe('RINGING');
    service.onModuleDestroy();
  });

  it('a food missed call leaves the note in the order chat and the push opens that chat', async () => {
    const { service, chat, push } = setup();
    const { call } = await service.startForFood(actor(DRIVER), ORDER);
    await vi.advanceTimersByTimeAsync(VOICE_CALL_RING_SECONDS * 1000 + 10);
    expect(await service.get(actor(CUSTOMER), call.id)).toMatchObject({
      status: 'MISSED',
    });
    expect(chat.recordCallNote).toHaveBeenCalledWith(
      'FoodOrder',
      ORDER,
      DRIVER,
      VOICE_MISSED_CALL_NOTE,
    );
    expect(push.send).toHaveBeenLastCalledWith(
      expect.objectContaining({
        userId: CUSTOMER,
        collapseKey: `call-${call.id}`,
        data: expect.objectContaining({
          eventType: 'Call.missed',
          aggregateType: 'FoodOrder',
          role: 'CUSTOMER',
          path: `/customer/food/orders/${ORDER}?chat=1`,
        }),
      }),
    );
    service.onModuleDestroy();
  });

  it('a food missed call to the driver opens the driver food chat', async () => {
    const { service, push } = setup();
    const { call } = await service.startForFood(actor(CUSTOMER), ORDER);
    await service.end(actor(CUSTOMER), call.id);
    expect(push.send).toHaveBeenLastCalledWith(
      expect.objectContaining({
        userId: DRIVER,
        data: expect.objectContaining({
          eventType: 'Call.missed',
          path: `/driver/food/${ORDER}?chat=1`,
        }),
      }),
    );
    service.onModuleDestroy();
  });

  it('caller hanging up while it rings is a missed call; callee declining is not', async () => {
    const { service, chat } = setup();
    const first = await service.startForRide(actor(CUSTOMER), RIDE);
    expect(await service.end(actor(CUSTOMER), first.call.id)).toMatchObject({
      status: 'MISSED',
      endReason: 'CANCELLED',
    });
    expect(chat.recordCallNote).toHaveBeenCalledTimes(1);
    const second = await service.startForRide(actor(CUSTOMER), RIDE);
    expect(await service.decline(actor(DRIVER), second.call.id)).toMatchObject({
      status: 'DECLINED',
    });
    expect(chat.recordCallNote).toHaveBeenCalledTimes(1);
    // The ring timer of a closed call does nothing.
    await vi.advanceTimersByTimeAsync(VOICE_CALL_RING_SECONDS * 1000 + 10);
    expect(chat.recordCallNote).toHaveBeenCalledTimes(1);
  });

  it('closes a call lazily when its ring window passed on another node', async () => {
    const { service, repo } = setup();
    const { call } = await service.startForRide(actor(CUSTOMER), RIDE);
    service.onModuleDestroy(); // no local timer, as if the call was placed on another API node
    vi.setSystemTime(Date.now() + VOICE_CALL_RING_SECONDS * 1000 + 1);
    await expectCode(
      service.accept(actor(DRIVER), call.id),
      'VOICE_CALL_NOT_RINGING',
    );
    expect((await repo.findById(call.id))?.status).toBe('MISSED');
  });
});
