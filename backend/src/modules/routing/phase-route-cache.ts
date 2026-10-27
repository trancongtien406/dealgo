import { Injectable } from '@nestjs/common';
import type { RouteGeometryView } from './route-geometry.js';
import type { RoutePhase } from './route-phase.js';

export type PhaseRouteAggregate = 'Ride' | 'FoodOrder';

export type CachedPhaseRoute = {
  phase: RoutePhase;
  route: RouteGeometryView;
  /** Epoch ms of the Directions lookup (throttle clock for the next re-route). */
  at: number;
};

/** A job lasts well under this; older entries are dropped on read. */
const PHASE_ROUTE_TTL_MS = 4 * 60 * 60_000;
const PHASE_ROUTE_MAX = 5_000;

/**
 * One cached road leg per active job (APPROACH, then TRIP). Shared by the realtime
 * phase-route push and the REST job snapshot, so a re-GET of the ride / order never
 * triggers its own Directions call while the leg is still valid. In-process: with
 * several API instances each one may look the leg up once.
 */
@Injectable()
export class PhaseRouteCache {
  private readonly entries = new Map<string, CachedPhaseRoute>();

  get(aggregate: PhaseRouteAggregate, id: string, now = Date.now()): CachedPhaseRoute | null {
    const key = `${aggregate}:${id}`;
    const hit = this.entries.get(key);
    if (!hit) return null;
    if (now - hit.at > PHASE_ROUTE_TTL_MS) {
      this.entries.delete(key);
      return null;
    }
    return hit;
  }

  /** The leg for [phase] only; a cached leg from the other phase is stale. */
  forPhase(aggregate: PhaseRouteAggregate, id: string, phase: RoutePhase, now = Date.now()): CachedPhaseRoute | null {
    const hit = this.get(aggregate, id, now);
    return hit && hit.phase === phase ? hit : null;
  }

  set(aggregate: PhaseRouteAggregate, id: string, entry: CachedPhaseRoute): void {
    const key = `${aggregate}:${id}`;
    this.entries.delete(key);
    if (this.entries.size >= PHASE_ROUTE_MAX) {
      this.entries.delete(this.entries.keys().next().value as string);
    }
    this.entries.set(key, entry);
  }

  forget(aggregate: PhaseRouteAggregate, id: string): void {
    this.entries.delete(`${aggregate}:${id}`);
  }
}
