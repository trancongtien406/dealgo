import { describe, expect, it, vi } from 'vitest';
import { MemoryChatRepository } from './chat.repository.js';
import { ChatService } from './chat.service.js';

function make(prefs?: { filterRecipients: ReturnType<typeof vi.fn> }) {
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const rides = {
    canSubscribe: vi.fn().mockResolvedValue(true),
    contactMeta: vi.fn().mockResolvedValue({ status: 'IN_TRIP', updatedAt: new Date() }),
    participantRoles: vi.fn().mockResolvedValue({ customerId: 'cust-1', driverId: 'drv-1' }),
  };
  const food = {
    canSubscribe: vi.fn().mockResolvedValue(true),
    chatAccess: vi.fn(async (userId: string, _orderId: string, channel: 'DRIVER' | 'MERCHANT') => {
      if (userId === 'cust-1') return { role: 'CUSTOMER', counterpartId: channel === 'DRIVER' ? 'drv-1' : 'm-1' };
      if (userId === 'drv-1' && channel === 'DRIVER') return { role: 'DRIVER', counterpartId: 'cust-1' };
      if (userId === 'm-1' && channel === 'MERCHANT') return { role: 'MERCHANT', counterpartId: 'cust-1' };
      return null;
    }),
    contactMeta: vi.fn().mockResolvedValue({ status: 'PICKED_UP', updatedAt: new Date() }),
    participantRoles: vi.fn().mockResolvedValue({ customerId: 'cust-1', driverId: 'drv-1', merchantId: 'm-1' }),
  };
  const settings = { getNumber: vi.fn().mockResolvedValue(30) };
  const svc = new ChatService(
    new MemoryChatRepository(),
    rides as never,
    food as never,
    settings as never,
    push as never,
    prefs as never,
  );
  return { svc, push };
}

describe('chat push', () => {
  it('pushes the other party with a tap path and never the message text', async () => {
    const { svc, push } = make();
    await svc.postForRide({ userId: 'cust-1' } as never, 'r1', 'số nhà 12 kiệt 5');
    expect(push.send).toHaveBeenCalledTimes(1);
    const sent = push.send.mock.calls[0][0];
    expect(sent.userId).toBe('drv-1');
    expect(sent.data).toMatchObject({ role: 'DRIVER', path: '/driver/rides/r1/active?chat=1', eventType: 'Chat.message' });
    expect(JSON.stringify(sent)).not.toContain('kiệt');
  });

  it('food chat reaches the customer, not the merchant, and bursts are throttled', async () => {
    const { svc, push } = make();
    await svc.postForFood({ userId: 'drv-1' } as never, 'o1', 'tới rồi');
    await svc.postForFood({ userId: 'drv-1' } as never, 'o1', 'ra lấy nhé');
    expect(push.send).toHaveBeenCalledTimes(1);
    expect(push.send.mock.calls[0][0]).toMatchObject({
      userId: 'cust-1',
      data: { role: 'CUSTOMER', path: '/customer/food/orders/o1?chat=1' },
    });
  });

  it('shop thread: customer → merchant push opens the merchant order; merchant → customer opens chat=shop', async () => {
    const { svc, push } = make();
    await svc.postForFood({ userId: 'cust-1' } as never, 'o2', 'ít cay', 'MERCHANT');
    expect(push.send.mock.calls[0][0]).toMatchObject({
      userId: 'm-1',
      title: 'Tin nhắn mới từ khách',
      data: { role: 'MERCHANT', channel: 'MERCHANT', path: '/merchant/orders/o2?chat=1' },
      collapseKey: 'chat-shop-o2',
    });
    await svc.postForFood({ userId: 'm-1' } as never, 'o2', 'dạ', 'MERCHANT');
    expect(push.send.mock.calls[1][0]).toMatchObject({
      userId: 'cust-1',
      title: 'Tin nhắn mới từ quán',
      data: { role: 'CUSTOMER', channel: 'MERCHANT', path: '/customer/food/orders/o2?chat=shop' },
    });
    // Never the driver.
    expect(push.send.mock.calls.map((c) => c[0].userId)).not.toContain('drv-1');
  });

  it('driver thread: customer → driver only, titled from the customer', async () => {
    const { svc, push } = make();
    await svc.postForFood({ userId: 'cust-1' } as never, 'o3', 'cổng sau');
    expect(push.send).toHaveBeenCalledTimes(1);
    expect(push.send.mock.calls[0][0]).toMatchObject({
      userId: 'drv-1',
      title: 'Tin nhắn mới từ khách',
      data: { role: 'DRIVER', channel: 'DRIVER', path: '/driver/food/o3?chat=1' },
    });
  });

  it('filters recipients by the chat preference, not ride/food', async () => {
    const prefs = { filterRecipients: vi.fn().mockResolvedValue([]) };
    const { svc, push } = make(prefs);
    await svc.postForRide({ userId: 'cust-1' } as never, 'r3', 'alo');
    expect(prefs.filterRecipients).toHaveBeenCalledWith(['drv-1'], 'CHAT');
    expect(push.send).not.toHaveBeenCalled();
  });

  it('a push failure does not fail the send', async () => {
    const { svc, push } = make();
    push.send.mockRejectedValueOnce(new Error('fcm down'));
    await expect(svc.postForRide({ userId: 'drv-1' } as never, 'r2', 'hi')).resolves.toMatchObject({ body: 'hi' });
  });
});
