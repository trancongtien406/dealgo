import { describe, expect, it } from 'vitest';
import { MemoryPlaceHistoryRepository } from './place-history.repository.js';
import { PLACE_HISTORY_MAX, PlaceHistoryService, placeHistoryKey } from './place-history.service.js';

const U = '00000000-0000-4000-8000-000000000001';
const OTHER = '00000000-0000-4000-8000-000000000002';

function setup() {
  const service = new PlaceHistoryService(new MemoryPlaceHistoryRepository());
  let t = Date.parse('2026-10-27T00:00:00Z');
  service.now = () => new Date((t += 1000));
  return service;
}

describe('PlaceHistoryService', () => {
  it('moves a repeated pick to the top instead of duplicating it', async () => {
    const s = setup();
    await s.record(U, { name: 'Chợ Hàn', lat: 16.0681, lng: 108.2231 });
    await s.record(U, { name: '12 Nguyễn Hoàng', address: '12 Nguyễn Hoàng, Hòa Cường', lat: 16.0603, lng: 108.2101 });
    await s.record(U, { name: 'cho han', lat: 16.0682, lng: 108.2233 });
    const { items } = await s.list(U);
    expect(items.map((i) => i.name)).toEqual(['cho han', '12 Nguyễn Hoàng']);
    expect(items[1]!.address).toBe('12 Nguyễn Hoàng, Hòa Cường');
  });

  it(`keeps the newest ${PLACE_HISTORY_MAX} per user`, async () => {
    const s = setup();
    for (let i = 0; i < PLACE_HISTORY_MAX + 3; i++) {
      await s.record(U, { name: `Nơi ${i}`, lat: 16 + i / 100, lng: 108 });
    }
    await s.record(OTHER, { name: 'Khác', lat: 10, lng: 106 });
    const { items } = await s.list(U);
    expect(items).toHaveLength(PLACE_HISTORY_MAX);
    expect(items[0]!.name).toBe(`Nơi ${PLACE_HISTORY_MAX + 2}`);
    expect((await s.list(OTHER)).items).toHaveLength(1);
  });

  it('deletes one entry (own only) and clears all', async () => {
    const s = setup();
    const a = await s.record(U, { name: 'A', lat: 16, lng: 108 });
    await s.record(U, { name: 'B', lat: 16.1, lng: 108 });
    await expect(s.remove(OTHER, a.id)).rejects.toMatchObject({ status: 404 });
    await s.remove(U, a.id);
    expect((await s.list(U)).items.map((i) => i.name)).toEqual(['B']);
    expect(await s.clear(U)).toEqual({ deleted: 1 });
    expect((await s.list(U)).items).toEqual([]);
  });

  it('keys places by folded name and ~110 m cell', () => {
    expect(placeHistoryKey('Chợ Hàn', 16.0681, 108.2231)).toBe(placeHistoryKey('cho han', 16.0684, 108.2233));
    expect(placeHistoryKey('Chợ Hàn', 16.068, 108.2235)).not.toBe(placeHistoryKey('Chợ Hàn', 16.07, 108.2235));
  });
});
