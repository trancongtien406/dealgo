import { describe, expect, it } from 'vitest';
import { isWithinContactWindow } from './contact-window.js';

describe('isWithinContactWindow', () => {
  const now = new Date('2026-10-14T12:00:00.000Z');

  it('allows active ride statuses regardless of age', () => {
    expect(
      isWithinContactWindow({
        kind: 'ride',
        status: 'IN_TRIP',
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
        now,
        windowMinutes: 120,
      }),
    ).toBe(true);
  });

  it('allows terminal ride within window', () => {
    expect(
      isWithinContactWindow({
        kind: 'ride',
        status: 'COMPLETED',
        updatedAt: new Date('2026-10-14T11:00:00.000Z'),
        now,
        windowMinutes: 120,
      }),
    ).toBe(true);
  });

  it('rejects terminal food outside window', () => {
    expect(
      isWithinContactWindow({
        kind: 'food',
        status: 'DELIVERED',
        updatedAt: new Date('2026-10-14T08:00:00.000Z'),
        now,
        windowMinutes: 120,
      }),
    ).toBe(false);
  });
});
