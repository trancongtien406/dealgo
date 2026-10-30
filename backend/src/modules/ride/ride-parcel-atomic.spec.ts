/** DEC-PROD-071: a parcel ride and its package row are created all-or-nothing. */
import { MemoryRideRepository } from './ride.repository.js';
import { MemoryRideParcelStore, type NewParcel } from './ride-parcel.store.js';

const now = new Date('2026-10-30T00:00:00Z');
const rideInput = (key: string) => ({
  customerId: 'c1',
  idempotencyKey: key,
  pickup: { lat: 16.05, lng: 108.2, label: 'A' },
  dropoff: { lat: 16.06, lng: 108.21, label: 'B' },
  offeredFareVnd: 30_000,
  referenceFareVnd: 30_000,
  vehicleClassCode: 'MOTORBIKE',
  expiresAt: new Date(now.getTime() + 60_000),
  now,
});
const parcel = (rideId: string): NewParcel => ({
  rideId, senderName: 'A', senderPhone: '0901234567', recipientName: 'B',
  recipientPhone: '0907654321', sizeClass: 'S', weightKg: 1, note: null, payer: 'SENDER',
  surchargeVnd: 0, serviceFeeVnd: 0, returnFeeVnd: 0, itemPhoto: null, recipientCode: '1234',
});

describe('ride + parcel atomic create (memory)', () => {
  it('rolls the ride back when the parcel insert fails', async () => {
    const rides = new MemoryRideRepository();
    await expect(
      rides.create(rideInput('k1'), async () => {
        throw new Error('parcel insert failed');
      }),
    ).rejects.toThrow('parcel insert failed');
    expect(await rides.listOpen(now)).toHaveLength(0);
    // Retry with the same key succeeds (no RIDE_ALREADY_OPEN ghost).
    const parcels = new MemoryRideParcelStore();
    const ride = await rides.create(rideInput('k1'), ({ rideId }) =>
      parcels.create(parcel(rideId)).then(() => undefined),
    );
    expect(await parcels.find(ride.id)).not.toBeNull();
  });

  it('idempotent replay returns the same ride and keeps one parcel row', async () => {
    const rides = new MemoryRideRepository();
    const parcels = new MemoryRideParcelStore();
    const hook = ({ rideId }: { rideId: string }) =>
      parcels.create(parcel(rideId)).then(() => undefined);
    const a = await rides.create(rideInput('k2'), hook);
    const b = await rides.create(rideInput('k2'), hook);
    expect(b.id).toBe(a.id);
    expect((await parcels.findMany([a.id])).size).toBe(1);
  });
});
