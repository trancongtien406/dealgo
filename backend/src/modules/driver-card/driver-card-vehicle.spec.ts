import { describe, expect, it } from 'vitest';
import { DriverCardService, phoneSharedFor, vehicleDisplayName } from './driver-card.service.js';

/** t81u: the offer card shows the driver's real vehicle, rating and completed trips. */
function service(metadata: Record<string, unknown>, status = 'APPROVED', subjectStatus = 'ASSIGNED') {
  const identity = {
    findUserById: async (id: string) => ({
      displayName: id === 'c1' ? 'Nguyễn Văn Khách Hàng Rất Dài Tên' : 'Tài xế A',
      avatarUrl: `https://cdn.example/${id}.png`,
      phone: id === 'c1' ? '+84901112222' : '+84903334444',
    }),
  };
  const partners = { findByUserAndRole: async () => ({ status, metadata }) };
  const ratings = { driverSummary: async () => ({ average: 4.9, count: 12 }) };
  const calls: string[][] = [];
  const rides = {
    countFinishedForDrivers: async (ids: string[]) => {
      calls.push(ids);
      return new Map([['d1', { completed: 1200, finished: 1250 }]]);
    },
    ratingSubject: async () => ({ customerId: 'c1', driverId: 'd1', status: subjectStatus }),
  };
  const food = { countFinishedForDrivers: async () => new Map([['d1', { completed: 34, finished: 35 }]]) };
  const svc = new DriverCardService(identity as never, partners as never, ratings as never, rides as never, food as never);
  return { svc, calls };
}

describe('driver card vehicle + trips (t81u)', () => {
  it('returns make/model, rating and completed rides+parcels+food in one card', async () => {
    const { svc, calls } = service({ vehicleBrand: ' Honda ', vehicleModel: 'Vision', vehicleType: 'Xe máy', vehiclePlate: '43B1-678.90' });
    await expect(svc.card('d1')).resolves.toMatchObject({
      vehicleBrand: 'Honda',
      vehicleModel: 'Vision',
      vehicleName: 'Honda Vision',
      vehicleType: 'Xe máy',
      vehiclePlate: '43B1-678.90',
      ratingAverage: 4.9,
      ratingCount: 12,
      completedTrips: 1234,
    });
    expect(calls).toEqual([['d1']]);
  });

  it('falls back to null (client shows the class) when make/model are missing or KYC not approved', async () => {
    await expect(service({ vehicleType: 'Xe máy' }).svc.card('d1')).resolves.toMatchObject({ vehicleName: null });
    await expect(service({ vehicleBrand: 'Honda', vehicleModel: 'AB' }, 'SUBMITTED').svc.card('d1')).resolves.toMatchObject({
      vehicleName: null,
    });
  });

  it('shares both phones and avatars only while the assigned ride is in progress', async () => {
    const live = service({}, 'APPROVED', 'DRIVER_EN_ROUTE').svc;
    await expect(live.forRide('c1', 'r1')).resolves.toMatchObject({
      phone: '+84903334444',
      avatarUrl: 'https://cdn.example/d1.png',
    });
    await expect(live.rideCustomer('d1', 'r1')).resolves.toMatchObject({
      displayName: 'Nguyễn Văn Khách Hàng Rất Dài Tên',
      phone: '+84901112222',
      avatarUrl: 'https://cdn.example/c1.png',
    });

    const done = service({}, 'APPROVED', 'COMPLETED').svc;
    await expect(done.forRide('c1', 'r1')).resolves.toMatchObject({ phone: null });
    await expect(done.rideCustomer('d1', 'r1')).resolves.toMatchObject({ phone: null });
    await expect(live.card('d1')).resolves.toMatchObject({ phone: null });
  });

  it('limits phone sharing to running job statuses', () => {
    for (const status of ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP', 'PICKED_UP']) {
      expect(phoneSharedFor(status)).toBe(true);
    }
    for (const status of ['NEGOTIATING', 'COMPLETED', 'CANCELLED', 'EXPIRED', 'DELIVERED', 'PLACED']) {
      expect(phoneSharedFor(status)).toBe(false);
    }
  });

  it('joins brand and model without repeating the brand', () => {
    expect(vehicleDisplayName('Mazda', '3')).toBe('Mazda 3');
    expect(vehicleDisplayName('Mitsubishi', 'Mitsubishi Xpander')).toBe('Mitsubishi Xpander');
    expect(vehicleDisplayName(null, 'Xpander')).toBe('Xpander');
    expect(vehicleDisplayName('Mercedes', null)).toBe('Mercedes');
    expect(vehicleDisplayName(null, null)).toBeNull();
  });
});
