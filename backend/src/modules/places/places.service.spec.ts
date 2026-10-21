import { describe, expect, it } from 'vitest';
import {
  MockMapsPort,
  UnavailableMapsPort,
  foldVietnamese,
} from '../../integrations/maps/maps-port.js';
import { PlacesService } from './places.service.js';

describe('PlacesService', () => {
  it('finds Da Nang places with or without diacritics', async () => {
    const places = new PlacesService(new MockMapsPort());
    const withMarks = await places.search('Chợ Hàn');
    expect(withMarks.available).toBe(true);
    expect(withMarks.items[0]).toMatchObject({
      name: 'Chợ Hàn',
      provider: 'mock',
    });
    expect(withMarks.items[0].lat).toBeCloseTo(16.068, 3);
    const folded = await places.search('cho han');
    expect(folded.items.map((p) => p.name)).toContain('Chợ Hàn');
    expect((await places.search('zzzz không có')).items).toEqual([]);
    expect((await places.search('a')).items).toEqual([]);
    expect(
      (await places.search('đà nẵng', 3)).items.length,
    ).toBeLessThanOrEqual(3);
  });

  it('reports an unconfigured provider instead of failing', async () => {
    const places = new PlacesService(new UnavailableMapsPort());
    expect(await places.search('chợ hàn')).toEqual({
      items: [],
      available: false,
    });
    expect(await places.reverse(16.068, 108.2235)).toEqual({
      place: null,
      available: false,
    });
  });

  it('names a GPS fix after the nearest landmark, keeping the fix', async () => {
    const places = new PlacesService(new MockMapsPort());
    const near = await places.reverse(16.0682, 108.2237);
    expect(near.place).toMatchObject({
      name: 'Gần Chợ Hàn',
      lat: 16.0682,
      lng: 108.2237,
    });
    expect((await places.reverse(10.77, 106.7)).place).toBeNull();
  });

  it('folds Vietnamese text for matching', () => {
    expect(foldVietnamese('  Đường  Bạch Đằng ')).toBe('duong bach dang');
  });
});
