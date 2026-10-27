import { describe, expect, it } from 'vitest';
import { DEFAULT_DRIVER_LOCATION_POLICY as cfg, haversineM, policyFor, rejectReason } from './driver-location-policy.js';

const now = new Date('2026-10-24T10:00:00Z');
const fresh = 120_000;

describe('driver location policy', () => {
  it('is fast on trip and sparse when idle', () => {
    expect(policyFor('ON_TRIP', cfg)).toEqual({ mode: 'ON_TRIP', intervalMs: 5000, minDistanceM: 10, maxSilenceMs: 30000 });
    expect(policyFor('IDLE', cfg)).toEqual({ mode: 'IDLE', intervalMs: 15000, minDistanceM: 50, maxSilenceMs: 60000 });
  });

  it('accepts a sane fix', () => {
    const prev = { lat: 10.77, lng: 106.7, at: new Date(now.getTime() - 5000) };
    expect(rejectReason({ lat: 10.7703, lng: 106.7, at: now, accuracyM: 8 }, prev, now, fresh)).toBeNull();
    expect(rejectReason({ lat: 10.77, lng: 106.7, at: now }, null, now, fresh)).toBeNull();
  });

  it('rejects future, stale, inaccurate, out-of-order and teleport fixes', () => {
    const prev = { lat: 10.77, lng: 106.7, at: new Date(now.getTime() - 5000) };
    expect(rejectReason({ lat: 10.77, lng: 106.7, at: new Date(now.getTime() + 60_000) }, null, now, fresh)).toBe('FUTURE');
    expect(rejectReason({ lat: 10.77, lng: 106.7, at: new Date(now.getTime() - 200_000) }, null, now, fresh)).toBe('STALE');
    expect(rejectReason({ lat: 10.77, lng: 106.7, at: now, accuracyM: 500 }, null, now, fresh)).toBe('LOW_ACCURACY');
    expect(rejectReason({ lat: 10.77, lng: 106.7, at: prev.at }, prev, now, fresh)).toBe('OUT_OF_ORDER');
    expect(rejectReason({ lat: 10.87, lng: 106.7, at: now }, prev, now, fresh)).toBe('IMPLAUSIBLE_JUMP');
  });

  it('haversine ~111m per 0.001 deg lat', () => {
    expect(haversineM({ lat: 10, lng: 106 }, { lat: 10.001, lng: 106 })).toBeCloseTo(111.2, 0);
  });
});
