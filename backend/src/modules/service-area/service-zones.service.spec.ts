import { beforeEach, describe, expect, it, vi } from 'vitest';
import { resetServiceRegionCatalog } from './service-regions.js';
import { OpsZonesService } from './service-zones.service.js';
import { ServiceRegionsService } from './service-regions.service.js';

describe('OpsZonesService', () => {
  let service: OpsZonesService;
  let listSettings: ReturnType<typeof vi.fn>;
  let rideGroupBy: ReturnType<typeof vi.fn>;
  let foodGroupBy: ReturnType<typeof vi.fn>;
  let vehicleClasses: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    resetServiceRegionCatalog();
    listSettings = vi.fn();
    rideGroupBy = vi.fn().mockResolvedValue([]);
    foodGroupBy = vi.fn().mockResolvedValue([]);
    vehicleClasses = vi.fn().mockResolvedValue([]);

    const prisma = {
      db: () => ({
        ride: { groupBy: rideGroupBy },
        foodOrder: { groupBy: foodGroupBy },
        rideVehicleClass: { findMany: vehicleClasses },
      }),
    };
    // Memory-mode regions (no DB handle) so zones come from the bootstrap defaults.
    const regions = new ServiceRegionsService(
      { db: () => null } as never,
      { record: vi.fn() } as never,
    );

    service = new OpsZonesService(
      {
        list: listSettings,
      } as never,
      prisma as never,
      regions,
    );
  });

  it('lists ACTIVE catalog regions with batched demand counts', async () => {
    rideGroupBy.mockResolvedValue([
      { serviceRegionCode: 'DN', _count: { _all: 3 } },
      { serviceRegionCode: 'HCM', _count: { _all: 1 } },
    ]);
    foodGroupBy.mockResolvedValue([
      { serviceRegionCode: 'DN', _count: { _all: 2 } },
    ]);

    const result = await service.listZones();
    const codes = result.items.map((z) => z.code);
    expect(codes).toEqual(expect.arrayContaining(['DN', 'HCM', 'HN', 'HP']));
    expect(codes).not.toContain('CT');

    const dn = result.items.find((z) => z.code === 'DN');
    expect(dn).toEqual(
      expect.objectContaining({
        code: 'DN',
        name: 'Đà Nẵng',
        status: 'ACTIVE',
        demandRideCount: 3,
        demandFoodCount: 2,
        demandCount: 5,
      }),
    );
    expect(result.items.find((z) => z.code === 'HCM')?.demandCount).toBe(1);
    expect(rideGroupBy).toHaveBeenCalledTimes(1);
    expect(foodGroupBy).toHaveBeenCalledTimes(1);
  });

  it('fail-softs demand counts when prisma throws', async () => {
    rideGroupBy.mockRejectedValue(new Error('db down'));

    const result = await service.listZones();
    expect(result.items.every((z) => z.demandCount === 0)).toBe(true);
  });

  it('filters by status and returns geometry for the map', async () => {
    const planned = await service.listZones({ status: 'PLANNED' });
    expect(planned.items.length).toBeGreaterThan(0);
    expect(planned.items.every((z) => z.status === 'PLANNED')).toBe(true);
    expect(planned.items.map((z) => z.code)).toContain('CT');

    const all = await service.listZones({ status: 'ALL' });
    expect(all.items.map((z) => z.code)).toEqual(
      expect.arrayContaining(['DN', 'HCM', 'CT']),
    );
    const dn = all.items.find((z) => z.code === 'DN');
    expect(dn).toEqual(
      expect.objectContaining({
        centerLat: expect.any(Number),
        centerLng: expect.any(Number),
        bbox: expect.objectContaining({ minLat: expect.any(Number) }),
      }),
    );
  });

  it('creates a zone that then appears in lists and the pricing-rule scope label', async () => {
    const created = await service.createZone(
      {
        code: 'qn',
        label: 'Quảng Ngãi',
        centerLat: 15.12,
        centerLng: 108.8,
        bbox: { minLat: 15.0, maxLat: 15.25, minLng: 108.7, maxLng: 108.95 },
        status: 'ACTIVE',
        reason: 'Mở rộng pilot miền Trung',
      },
      'ops-user-1',
    );
    expect(created).toEqual(
      expect.objectContaining({ code: 'QN', name: 'Quảng Ngãi', status: 'ACTIVE' }),
    );

    const active = await service.listZones();
    expect(active.items.map((z) => z.code)).toContain('QN');

    listSettings.mockResolvedValue([]);
    const rules = await service.listRules({ page: 1, limit: 5 });
    expect(rules.items[0].zone).toContain('Quảng Ngãi');
  });

  it('disables a zone via patch and refuses to disable the last ACTIVE one', async () => {
    const disabled = await service.patchZone(
      'HP',
      { status: 'PLANNED', reason: 'Tạm dừng Hải Phòng' },
      'ops-user-1',
    );
    expect(disabled.status).toBe('PLANNED');
    expect((await service.listZones()).items.map((z) => z.code)).not.toContain('HP');

    await service.patchZone('HN', { status: 'PLANNED', reason: 'Tạm dừng Hà Nội' }, 'u');
    await service.patchZone('HCM', { status: 'PLANNED', reason: 'Tạm dừng HCM' }, 'u');
    await expect(
      service.patchZone('DN', { status: 'PLANNED', reason: 'Tạm dừng Đà Nẵng' }, 'u'),
    ).rejects.toMatchObject({ errorCode: 'SERVICE_REGION_LAST_ACTIVE' });
  });

  it('builds paginated pricing rules from platform settings', async () => {
    listSettings.mockResolvedValue([
      {
        key: 'RIDE_MIN_FARE_VND',
        value: '15000',
        valueType: 'number',
        source: 'db',
        openIds: [],
        updatedAt: '2026-10-14T00:00:00.000Z',
        updatedByUserId: null,
      },
      {
        key: 'DRIVER_SEARCH_RADIUS_KM',
        value: '5',
        valueType: 'number',
        source: 'env',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
      {
        key: 'FOOD_MIN_DELIVERY_VND',
        value: '12000',
        valueType: 'number',
        source: 'db',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
      {
        key: 'RIDE_MAX_FARE_VND',
        value: '500000',
        valueType: 'number',
        source: 'env',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
      {
        key: 'RIDE_REFERENCE_VND_PER_KM',
        value: '8000',
        valueType: 'number',
        source: 'env',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
      {
        key: 'FOOD_MAX_DELIVERY_VND',
        value: '100000',
        valueType: 'number',
        source: 'env',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
    ]);

    const page = await service.listRules({ page: 1, limit: 3, q: 'ride' });
    expect(page.total).toBe(3);
    expect(page.items).toHaveLength(3);
    expect(page.items.every((r) => r.service === 'RIDE' || r.code.includes('RIDE'))).toBe(
      true,
    );
    expect(page.items[0]).toEqual(
      expect.objectContaining({
        code: 'RIDE_MIN_FARE_VND',
        name: 'Giá sàn chuyến xe',
        service: 'RIDE',
        status: 'ACTIVE',
        value: '15000',
        unit: 'VND',
      }),
    );
    expect(page.items[0].zone).toContain('Đà Nẵng');
  });

  it('Shows live per-class Ride prices instead of the seed-only RIDE_* settings', async () => {
    listSettings.mockResolvedValue([
      {
        key: 'RIDE_MIN_FARE_VND',
        value: '15000',
        valueType: 'number',
        source: 'db',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
      {
        key: 'FOOD_MIN_DELIVERY_VND',
        value: '12000',
        valueType: 'number',
        source: 'db',
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      },
    ]);
    vehicleClasses.mockResolvedValue([
      {
        code: 'MOTORBIKE',
        name: 'Xe máy',
        baseFareVnd: 0,
        perKmVnd: 8000,
        minFareVnd: 12000,
        maxFareVnd: 500000,
        updatedAt: new Date('2026-10-26T00:00:00.000Z'),
      },
    ]);

    const page = await service.listRules({ page: 1, limit: 50 });
    const codes = page.items.map((r) => r.code);
    expect(codes).not.toContain('RIDE_MIN_FARE_VND');
    expect(codes).not.toContain('RIDE_MAX_FARE_VND');
    expect(codes).not.toContain('RIDE_REFERENCE_VND_PER_KM');
    expect(page.items.find((r) => r.code === 'RIDE_MOTORBIKE_MIN_FARE_VND')).toEqual(
      expect.objectContaining({ name: 'Giá sàn chuyến xe · Xe máy', value: '12000', service: 'RIDE' }),
    );
    expect(page.items.find((r) => r.code === 'RIDE_MOTORBIKE_PER_KM_VND')?.value).toBe('8000');
    expect(codes).toContain('FOOD_MIN_DELIVERY_VND');
  });
});
