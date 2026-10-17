import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getServiceRegion,
  resetServiceRegionCatalog,
} from './service-regions.js';
import {
  ServiceRegionsService,
  validateServiceRegionShape,
} from './service-regions.service.js';

const validBBox = { minLat: 15.0, maxLat: 15.25, minLng: 108.7, maxLng: 108.95 };

function memoryService() {
  const record = vi.fn();
  const service = new ServiceRegionsService(
    { db: () => null } as never,
    { record } as never,
  );
  return { service, record };
}

describe('validateServiceRegionShape', () => {
  const base = {
    code: 'QN',
    label: 'Quảng Ngãi',
    centerLat: 15.12,
    centerLng: 108.8,
    bbox: validBBox,
  };

  it('accepts a sane zone', () => {
    expect(() => validateServiceRegionShape(base)).not.toThrow();
  });

  it.each([
    ['bad code', { code: '1X' }],
    ['code too long', { code: 'ABCDEFGHI' }],
    ['label too short', { label: 'x' }],
    ['outside Vietnam', { centerLat: 40, bbox: { ...validBBox, minLat: 39, maxLat: 41 } }],
    ['swapped lat/lng', { centerLat: 108.8, centerLng: 15.12 }],
    ['min >= max', { bbox: { ...validBBox, minLat: 15.3 } }],
    ['bbox too large', { bbox: { minLat: 12, maxLat: 16, minLng: 108.7, maxLng: 108.95 } }],
    ['center outside bbox', { centerLat: 16.0 }],
  ])('rejects %s', (_name, override) => {
    expect(() => validateServiceRegionShape({ ...base, ...override })).toThrow(
      expect.objectContaining({ errorCode: 'SERVICE_REGION_INVALID' }),
    );
  });
});

describe('ServiceRegionsService (memory mode)', () => {
  beforeEach(() => resetServiceRegionCatalog());

  const input = {
    code: 'qn',
    label: 'Quảng Ngãi',
    centerLat: 15.12,
    centerLng: 108.8,
    bbox: validBBox,
  };

  it('creates PLANNED by default, normalizes code, publishes catalog and audits', async () => {
    const { service, record } = memoryService();

    const created = await service.create(input, 'Khảo sát pilot', 'ops-1');

    expect(created).toEqual(
      expect.objectContaining({ code: 'QN', status: 'PLANNED', sortOrder: 12 }),
    );
    expect(getServiceRegion('QN')?.label).toBe('Quảng Ngãi');
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({
        entityType: 'SERVICE_REGION',
        entityId: created.id,
        reason: 'Khảo sát pilot',
      }),
    );
  });

  it('rejects duplicate code and duplicate label with 409', async () => {
    const { service } = memoryService();
    await service.create(input, 'reason ok', 'ops-1');

    await expect(
      service.create({ ...input, label: 'Tên khác' }, 'reason ok', 'ops-1'),
    ).rejects.toMatchObject({ errorCode: 'SERVICE_REGION_CODE_TAKEN' });
    await expect(
      service.create({ ...input, code: 'QN2' }, 'reason ok', 'ops-1'),
    ).rejects.toMatchObject({ errorCode: 'SERVICE_REGION_LABEL_TAKEN' });
    await expect(
      service.create({ ...input, code: 'DN', label: 'Khác hẳn' }, 'reason ok', 'ops-1'),
    ).rejects.toMatchObject({ errorCode: 'SERVICE_REGION_CODE_TAKEN' });
  });

  it('patches label/status and 404s for unknown codes', async () => {
    const { service } = memoryService();

    const updated = await service.update(
      'ct',
      { status: 'ACTIVE', label: 'Cần Thơ (pilot)' },
      'Mở Cần Thơ',
      'ops-1',
    );
    expect(updated).toEqual(
      expect.objectContaining({ code: 'CT', status: 'ACTIVE', label: 'Cần Thơ (pilot)' }),
    );
    expect(getServiceRegion('CT')?.status).toBe('ACTIVE');

    await expect(service.update('ZZZ', { label: 'Nope' }, 'reason ok', 'ops-1')).rejects.toMatchObject({
      errorCode: 'SERVICE_REGION_NOT_FOUND',
    });
  });

  it('keeps stored zones intact when a patch fails validation', async () => {
    const { service } = memoryService();
    await expect(
      service.update('DN', { centerLat: 50 }, 'reason ok', 'ops-1'),
    ).rejects.toMatchObject({ errorCode: 'SERVICE_REGION_INVALID' });
    expect(getServiceRegion('DN')?.centerLat).toBeCloseTo(16.0544);
  });
});
