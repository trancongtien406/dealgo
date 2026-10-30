import { MemoryRideParcelStore, type NewParcel } from './ride-parcel.store.js';

const input = (rideId: string): NewParcel => ({
  rideId,
  senderName: 'A',
  senderPhone: '0901234567',
  recipientName: 'B',
  recipientPhone: '0907654321',
  sizeClass: 'S',
  weightKg: 1,
  note: null,
  payer: 'SENDER',
  surchargeVnd: 0,
  serviceFeeVnd: 0,
  returnFeeVnd: 0,
  itemPhoto: null,
  recipientCode: '1234',
});

describe('MemoryRideParcelStore (DEC-PROD-071)', () => {
  it('create is idempotent per ride', async () => {
    const store = new MemoryRideParcelStore();
    await store.create(input('r1'));
    const again = await store.create({ ...input('r1'), senderName: 'other' });
    expect(again.senderName).toBe('A');
    expect((await store.findMany(['r1', 'r2'])).size).toBe(1);
  });

  it('update only applies from the allowed outcomes', async () => {
    const store = new MemoryRideParcelStore();
    await store.create(input('r1'));
    expect(await store.update('r1', ['RETURNING'], { outcome: 'RETURNED' })).toBeNull();
    expect((await store.update('r1', ['PENDING'], { outcome: 'RETURNING' }))?.outcome).toBe('RETURNING');
    expect(await store.update('r1', ['PENDING'], { outcome: 'DELIVERED' })).toBeNull();
  });

  it('caps recipient code attempts', async () => {
    const store = new MemoryRideParcelStore();
    await store.create(input('r1'));
    expect(await store.reserveCodeAttempt('r1', 2)).toBe(true);
    expect(await store.reserveCodeAttempt('r1', 2)).toBe(true);
    expect(await store.reserveCodeAttempt('r1', 2)).toBe(false);
  });
});
