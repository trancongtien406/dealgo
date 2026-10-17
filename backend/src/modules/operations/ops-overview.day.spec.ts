import { describe, expect, it } from 'vitest';
import { startOfTodayHoChiMinh } from './ops-overview.day.js';

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
