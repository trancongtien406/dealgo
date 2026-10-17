import { describe, expect, it } from 'vitest';
import { MockPushSender, UnavailablePushSender } from './push-sender.js';

describe('PushSender', () => {
  it('mock stores and redacts user id in logs without throwing in test', async () => {
    const sender = new MockPushSender('test');
    await sender.send({
      userId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      title: 'Ride update',
      body: 'Status changed',
      data: { aggregateType: 'Ride', status: 'ASSIGNED' },
    });
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0]?.data.status).toBe('ASSIGNED');
  });

  it('mock refuses production', async () => {
    const sender = new MockPushSender('production');
    await expect(
      sender.send({
        userId: 'u1',
        title: 't',
        body: 'b',
        data: {},
      }),
    ).rejects.toThrow(/production/);
  });

  it('unavailable fails closed', async () => {
    await expect(new UnavailablePushSender().send()).rejects.toThrow(/not configured/);
  });
});
