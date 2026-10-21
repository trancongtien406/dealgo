import { completionRate, mergeJobCounts } from './driver-job-counts.js';

describe('driver job counts (DEC-PROD-034)', () => {
  it('merges ride and food counts per driver', () => {
    const merged = mergeJobCounts(
      mergeJobCounts(new Map(), new Map([['d1', { completed: 2, finished: 3 }]])),
      new Map([
        ['d1', { completed: 1, finished: 1 }],
        ['d2', { completed: 0, finished: 2 }],
      ]),
    );
    expect(merged.get('d1')).toEqual({ completed: 3, finished: 4 });
    expect(merged.get('d2')).toEqual({ completed: 0, finished: 2 });
  });

  it('rate is completed / finished, null without finished jobs', () => {
    expect(completionRate({ completed: 3, finished: 4 })).toBe(0.75);
    expect(completionRate({ completed: 2, finished: 3 })).toBe(0.667);
    expect(completionRate({ completed: 0, finished: 2 })).toBe(0);
    expect(completionRate({ completed: 0, finished: 0 })).toBeNull();
  });
});
