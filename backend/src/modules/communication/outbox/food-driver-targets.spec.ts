import { describe, expect, it } from 'vitest';
import { foodDriverTargetsFromPayload } from './outbox-relay.service.js';

describe('foodDriverTargetsFromPayload', () => {
  it('returns the assigned driver and drivers whose offer was LOST (deduped)', () => {
    expect(
      foodDriverTargetsFromPayload({
        status: 'ASSIGNED',
        assignedDriverId: 'd1',
        lostDriverIds: ['d2', 'd3', 'd2', '', 5],
      }),
    ).toEqual(['d1', 'd2', 'd3']);
  });

  it('ignores malformed payloads', () => {
    expect(foodDriverTargetsFromPayload(null)).toEqual([]);
    expect(foodDriverTargetsFromPayload([])).toEqual([]);
    expect(foodDriverTargetsFromPayload({ status: 'READY' })).toEqual([]);
  });
});
