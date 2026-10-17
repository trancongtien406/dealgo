import { describe, expect, it } from 'vitest';
import { classifyFoodException, classifyRideException } from './ops-exceptions.classify.js';

describe('ops exception classifiers', () => {
  const stuckBefore = new Date('2026-10-14T10:00:00.000Z');
  const recentAfter = new Date('2026-10-07T12:00:00.000Z');

  it('marks old mid-lifecycle rides as stuck', () => {
    expect(
      classifyRideException(
        'IN_TRIP',
        new Date('2026-10-14T08:00:00.000Z'),
        stuckBefore,
        recentAfter,
      ),
    ).toBe('stuck');
  });

  it('marks recent cancelled rides as terminal', () => {
    expect(
      classifyRideException(
        'CANCELLED',
        new Date('2026-10-14T11:00:00.000Z'),
        stuckBefore,
        recentAfter,
      ),
    ).toBe('terminal');
  });

  it('ignores fresh assigned rides', () => {
    expect(
      classifyRideException(
        'ASSIGNED',
        new Date('2026-10-14T11:30:00.000Z'),
        stuckBefore,
        recentAfter,
      ),
    ).toBeNull();
  });

  it('marks recent failed food as terminal', () => {
    expect(
      classifyFoodException(
        'FAILED',
        new Date('2026-10-14T11:00:00.000Z'),
        stuckBefore,
        recentAfter,
      ),
    ).toBe('terminal');
  });
});
