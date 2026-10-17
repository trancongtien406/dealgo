import { outboxEventKey, outboxEventType, shouldEmitFoodStatus, shouldEmitRideStatus } from './outbox.write.js';

describe('outbox.write helpers', () => {
  it('emits notable ride and food statuses only', () => {
    expect(shouldEmitRideStatus('ASSIGNED')).toBe(true);
    expect(shouldEmitRideStatus('EXPIRED')).toBe(true);
    expect(shouldEmitRideStatus('NEGOTIATING')).toBe(false);
    expect(shouldEmitFoodStatus('DELIVERED')).toBe(true);
    expect(shouldEmitFoodStatus('PLACED')).toBe(false);
  });

  it('builds stable idempotent event keys', () => {
    expect(outboxEventKey('Ride', 'ride-1', 'ASSIGNED')).toBe('Ride:ride-1:status:ASSIGNED');
    expect(outboxEventType('FoodOrder', 'DELIVERED')).toBe('FoodOrder.status.DELIVERED');
  });
});
