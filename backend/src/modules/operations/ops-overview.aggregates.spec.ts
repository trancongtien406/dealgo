import {
  statusCount,
  statusCountMap,
  sumStatusCounts,
  sumStatuses,
} from './ops-overview.aggregates.js';
import { RIDE_OPEN_STATUSES } from './ops-overview.constants.js';

describe('ops-overview aggregates', () => {
  it('maps GROUP BY rows and sums totals / selected statuses', () => {
    const map = statusCountMap([
      { status: 'NEGOTIATING', cnt: 3n },
      { status: 'ASSIGNED', cnt: 5 },
      { status: 'COMPLETED', cnt: 100n },
      { status: 'CANCELLED', cnt: 20n },
    ]);

    expect(statusCount(map, 'NEGOTIATING')).toBe(3);
    expect(statusCount(map, 'ASSIGNED')).toBe(5);
    expect(statusCount(map, 'MISSING')).toBe(0);
    expect(sumStatusCounts(map)).toBe(128);
    expect(sumStatuses(map, RIDE_OPEN_STATUSES)).toBe(8);
  });
});
