import { describe, expect, it, vi } from 'vitest';
import { PaymentStatusBus } from '../../payment/checkout/payment-status-bus.js';
import { PaymentStatusBridgeService } from './payment-status-bridge.service.js';

function make(roles: Record<string, { customerId: string } | null>) {
  const emit = vi.fn();
  const fanout = { emitPaymentStatus: emit };
  const lookup = { participantRoles: vi.fn(async (id: string) => roles[id] ?? null) };
  const bus = new PaymentStatusBus();
  const bridge = new PaymentStatusBridgeService(fanout as never, lookup as never, lookup as never, bus);
  bridge.onModuleInit();
  return { emit, bus, bridge };
}

describe('PaymentStatusBridgeService', () => {
  it('emits paymentStatus to the job customer only', async () => {
    const { emit, bridge } = make({ r1: { customerId: 'cust-1' } });
    await bridge.forward({ entityType: 'RIDE', entityId: 'r1', intentId: 'i1', status: 'PAID', occurredAt: 't' });
    expect(emit).toHaveBeenCalledWith('cust-1', { entityType: 'RIDE', entityId: 'r1', intentId: 'i1', status: 'PAID', occurredAt: 't' });
  });

  it('skips unknown jobs and stops after destroy', async () => {
    const { emit, bus, bridge } = make({});
    await bridge.forward({ entityType: 'FOOD_ORDER', entityId: 'x', intentId: 'i', status: 'FAILED', occurredAt: 't' });
    bridge.onModuleDestroy();
    bus.publish({ entityType: 'RIDE', entityId: 'x', intentId: 'i', status: 'PAID', occurredAt: 't' });
    await new Promise((r) => setTimeout(r, 0));
    expect(emit).not.toHaveBeenCalled();
  });
});
