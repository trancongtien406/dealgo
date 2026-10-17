import { describe, expect, it } from 'vitest';
import { DeliveryService } from './delivery.service.js';

describe('DeliveryService', () => {
  const delivery = new DeliveryService();

  it('manages delivery task lifecycle', () => {
    const task = delivery.createTask({
      orderId: 'order-123',
      pickupAddress: 'Quán ăn ngon',
      dropoffAddress: 'Nhà khách hàng',
    });

    expect(task.id).toBeDefined();
    expect(task.status).toBe('PENDING');

    const assigned = delivery.assignDriver(task.id, 'driver-456');
    expect(assigned?.status).toBe('ASSIGNED');
    expect(assigned?.driverId).toBe('driver-456');

    const pickedUp = delivery.markPickedUp(task.id);
    expect(pickedUp?.status).toBe('PICKED_UP');

    const completed = delivery.markCompleted(task.id);
    expect(completed?.status).toBe('COMPLETED');
  });

  it('returns null for non-existing task', () => {
    expect(delivery.getTask('non-existent')).toBeNull();
    expect(delivery.assignDriver('non-existent', 'driver-1')).toBeNull();
  });
});
