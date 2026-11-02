import { describe, expect, it } from 'vitest';
import { afterEach } from 'vitest';
import {
  DEFAULT_SERVICE_REGION_CODE,
  activeServiceRegions,
  activeServiceRegionsLabel,
  getServiceRegion,
  inferRegionCodeFromCoords,
  inferRegionCodeFromLabel,
  normalizeRegionFilter,
  resetServiceRegionCatalog,
  resolveServiceRegionCode,
  setServiceRegionCatalog,
  SERVICE_REGIONS,
} from './service-regions.js';

describe('service-regions', () => {
  it('exposes ACTIVE DN and HCM for pilot dual-city seed', () => {
    const codes = activeServiceRegions().map((r) => r.code);
    expect(codes).toEqual(expect.arrayContaining(['DN', 'HCM', 'HN', 'HP']));
    expect(codes).not.toContain('CT');
  });

  it('classifies DN / HCM coords by bbox', () => {
    expect(inferRegionCodeFromCoords(16.0611, 108.2272)).toBe('DN');
    expect(inferRegionCodeFromCoords(10.7719, 106.7042)).toBe('HCM');
    expect(inferRegionCodeFromCoords(21.0285, 105.8542)).toBe('HN');
  });

  it('covers Hội An inside merged Đà Nẵng (phố cổ, An Bàng, Cửa Đại)', () => {
    expect(inferRegionCodeFromCoords(15.8771, 108.3287)).toBe('DN');
    expect(inferRegionCodeFromCoords(15.9135, 108.3412)).toBe('DN');
    expect(inferRegionCodeFromCoords(15.8960, 108.3880)).toBe('DN');
  });

  it('infers from Vietnamese labels', () => {
    expect(inferRegionCodeFromLabel('Hải Châu, Đà Nẵng')).toBe('DN');
    expect(inferRegionCodeFromLabel('Quận 1, Hồ Chí Minh')).toBe('HCM');
    expect(inferRegionCodeFromLabel('Hoàn Kiếm, Hà Nội')).toBe('HN');
  });

  it('normalizes zone filter codes', () => {
    expect(normalizeRegionFilter('DN')).toBe('DN');
    expect(normalizeRegionFilter('ALL')).toBeUndefined();
    expect(normalizeRegionFilter('Đà Nẵng')).toBe('DN');
  });

  it('falls back to default DN for ambiguous pilot rows', () => {
    expect(resolveServiceRegionCode({ label: 'somewhere unknown' })).toBe(
      DEFAULT_SERVICE_REGION_CODE,
    );
  });

  describe('runtime catalog (Admin-created zones)', () => {
    afterEach(() => resetServiceRegionCatalog());

    const quangNgai = {
      code: 'QN',
      label: 'Quảng Ngãi',
      centerLat: 15.12,
      centerLng: 108.8,
      bbox: { minLat: 15.0, maxLat: 15.25, minLng: 108.7, maxLng: 108.95 },
      status: 'ACTIVE' as const,
    };

    it('uses a swapped-in catalog for every lookup', () => {
      setServiceRegionCatalog([...SERVICE_REGIONS, quangNgai]);

      expect(getServiceRegion('qn')?.label).toBe('Quảng Ngãi');
      expect(inferRegionCodeFromCoords(15.12, 108.8)).toBe('QN');
      expect(inferRegionCodeFromLabel('123 Trần Hưng Đạo, Quảng Ngãi')).toBe('QN');
      expect(normalizeRegionFilter('Quảng Ngãi')).toBe('QN');
      expect(activeServiceRegions().map((r) => r.code)).toContain('QN');
      expect(activeServiceRegionsLabel()).toContain('Quảng Ngãi');
    });

    it('stops resolving a zone once it is no longer in the catalog', () => {
      setServiceRegionCatalog([...SERVICE_REGIONS, quangNgai]);
      resetServiceRegionCatalog();

      expect(getServiceRegion('QN')).toBeUndefined();
      expect(inferRegionCodeFromCoords(15.12, 108.8)).toBeNull();
    });

    it('derives the pilot label only from ACTIVE zones', () => {
      setServiceRegionCatalog([
        { ...quangNgai, status: 'PLANNED' },
        { ...SERVICE_REGIONS[0] },
      ]);

      expect(activeServiceRegionsLabel()).toBe('Đà Nẵng');
    });
  });
});
