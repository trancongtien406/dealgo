import { MemoryRideShareRepository } from './ride-share.repository.js';
import { RIDE_SHARE_AFTER_END_MS, RideShareService } from './ride-share.service.js';

function service(status: string, updatedAt: Date) {
  const ride = {
    id: 'ride-1',
    customerId: 'cust-1',
    status,
    pickup: { lat: 0, lng: 0, label: 'A' },
    dropoff: { lat: 0, lng: 0, label: 'B' },
    assignedDriverId: 'drv-1',
    updatedAt,
  };
  const rides = { shareSnapshot: async () => ride } as never;
  const cards = {
    card: async () => ({ displayName: 'Lê Thị Hoa', vehiclePlate: '43B1', vehicleType: 'Xe máy', ratingAverage: 4.8 }),
  } as never;
  const config = { get: () => 'https://dealgo.vn/' } as never;
  return { svc: new RideShareService(new MemoryRideShareRepository(), rides, cards, config), ride };
}

describe('RideShareService expiry', () => {
  const t0 = new Date('2026-10-19T03:00:00.000Z');

  it('uses the configured origin and expires 12h after creation', async () => {
    const { svc } = service('IN_TRIP', t0);
    const link = await svc.create('cust-1', 'ride-1', t0);
    expect(link.url.startsWith('https://dealgo.vn/chia-se-chuyen/')).toBe(true);
    expect((await svc.view(link.token, new Date(t0.getTime() + 60_000))).driver?.name).toBe('Hoa L.');
    await expect(svc.view(link.token, new Date(t0.getTime() + 12 * 3600_000))).rejects.toMatchObject({
      status: 410,
    });
  });

  it('stays readable briefly after the trip ends, then expires', async () => {
    const { svc, ride } = service('IN_TRIP', t0);
    const link = await svc.create('cust-1', 'ride-1', t0);
    ride.status = 'COMPLETED';
    expect((await svc.view(link.token, new Date(t0.getTime() + 60_000))).status).toBe('COMPLETED');
    await expect(
      svc.view(link.token, new Date(t0.getTime() + RIDE_SHARE_AFTER_END_MS + 1)),
    ).rejects.toMatchObject({ status: 410 });
  });
});
