import { describe, expect, it } from 'vitest';
import { RideViewerPresence } from './ride-viewer-presence.js';

describe('RideViewerPresence', () => {
  it('counts distinct drivers and drops them after the view window', () => {
    const presence = new RideViewerPresence();
    const t0 = 1_000_000;
    expect(presence.touch('ride-1', 'd1', t0)).toBe(1);
    expect(presence.touch('ride-1', 'd1', t0 + 5_000)).toBe(1);
    expect(presence.touch('ride-1', 'd2', t0 + 5_000)).toBe(2);
    expect(presence.count('ride-1', t0 + 19_000)).toBe(2);
    expect(presence.leave('ride-1', 'd2', t0 + 19_000)).toBe(1);
    expect(presence.count('ride-1', t0 + 30_000)).toBe(0);
    expect(presence.count('ride-2', t0)).toBe(0);
  });
});
