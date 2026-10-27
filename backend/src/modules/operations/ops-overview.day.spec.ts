import { describe, expect, it } from 'vitest';
import { hoChiMinhDayKey, hoChiMinhDayRange, startOfTodayHoChiMinh } from './ops-overview.day.js';

describe('startOfTodayHoChiMinh', () => {
  it('returns 17:00 UTC previous day when local is after midnight ICT', () => {
    // 2026-10-14 00:30 ICT = 2026-10-13 17:30 UTC
    const now = new Date('2026-10-13T17:30:00.000Z');
    expect(startOfTodayHoChiMinh(now).toISOString()).toBe('2026-10-13T17:00:00.000Z');
  });

  it('returns 17:00 UTC same calendar UTC day when still evening previous ICT day', () => {
    // 2026-10-13 23:00 ICT = 2026-10-13 16:00 UTC → still 2026-10-13 ICT
    const now = new Date('2026-10-13T16:00:00.000Z');
    expect(startOfTodayHoChiMinh(now).toISOString()).toBe('2026-10-12T17:00:00.000Z');
  });
});

describe('hoChiMinhDayRange', () => {
  it('defaults to the current Vietnam day', () => {
    const range = hoChiMinhDayRange({}, new Date('2026-10-13T17:30:00.000Z'));
    expect(range).toMatchObject({ from: '2026-10-14', to: '2026-10-14', days: ['2026-10-14'] });
    expect(range?.start.toISOString()).toBe('2026-10-13T17:00:00.000Z');
    expect(range?.end.toISOString()).toBe('2026-10-14T17:00:00.000Z');
  });

  it('covers an inclusive multi-day range', () => {
    const range = hoChiMinhDayRange({ from: '2026-10-01', to: '2026-10-03' });
    expect(range?.days).toEqual(['2026-10-01', '2026-10-02', '2026-10-03']);
    expect(range?.end.toISOString()).toBe('2026-10-03T17:00:00.000Z');
  });

  it('rejects malformed, reversed and too-long ranges', () => {
    expect(hoChiMinhDayRange({ from: '2026-13-01' })).toBeNull();
    expect(hoChiMinhDayRange({ from: '2026-10-05', to: '2026-10-01' })).toBeNull();
    expect(hoChiMinhDayRange({ from: '2026-01-01', to: '2026-12-31' })).toBeNull();
  });

  it('maps an instant to its Vietnam day key', () => {
    expect(hoChiMinhDayKey(new Date('2026-10-13T16:59:59.000Z'))).toBe('2026-10-13');
    expect(hoChiMinhDayKey(new Date('2026-10-13T17:00:00.000Z'))).toBe('2026-10-14');
  });
});
