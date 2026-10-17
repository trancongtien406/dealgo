import type {
  CancelInput,
  CreateRideInput,
  DriverLifecycleInput,
  OfferInput,
  OpenRideListing,
  OpsCancelInput,
  OpsReassignInput,
  RideSnapshot,
  SelectInput,
} from './ride-ledger.js';
import { RideLedger } from './ride-ledger.js';
import { RideRuleError } from './ride.error.js';

export type OpsRidePage = {
  items: RideSnapshot[];
  total: number;
};

export type OpsInterveneResult = {
  ride: RideSnapshot;
  auditId: string;
};

export interface RideRepository {
  create(input: CreateRideInput): Promise<RideSnapshot>;
  findById(id: string, now: Date): Promise<RideSnapshot | null>;
  listOpen(now: Date, limit?: number): Promise<OpenRideListing[]>;
  listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<OpsRidePage>;
  listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): Promise<OpsRidePage>;
  offer(input: OfferInput): Promise<RideSnapshot>;
  select(input: SelectInput): Promise<RideSnapshot>;
  cancel(input: CancelInput): Promise<RideSnapshot>;
  opsCancel(
    input: OpsCancelInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult>;
  opsReassign(
    input: OpsReassignInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult>;
  markEnRoute(input: DriverLifecycleInput): Promise<RideSnapshot>;
  markArrived(input: DriverLifecycleInput): Promise<RideSnapshot>;
  startTrip(input: DriverLifecycleInput): Promise<RideSnapshot>;
  complete(input: DriverLifecycleInput): Promise<RideSnapshot>;
  expireDue(now: Date, limit?: number): Promise<string[]>;
}

export class MemoryRideRepository implements RideRepository {
  private readonly ledger = new RideLedger();
  private tail: Promise<void> = Promise.resolve();

  create(input: CreateRideInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.create(input)));
  }

  findById(id: string, now: Date): Promise<RideSnapshot | null> {
    return this.run(() => this.ledger.read(id, now));
  }

  listOpen(now: Date, limit?: number): Promise<OpenRideListing[]> {
    return this.run(() => this.ledger.listOpen(now, limit));
  }

  listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<OpsRidePage> {
    return this.run(() => this.ledger.listPage(page, limit, now, filter));
  }

  listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): Promise<OpsRidePage> {
    return this.run(() => this.ledger.listForCustomer(customerId, page, limit, now));
  }

  offer(input: OfferInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.offer(input)));
  }

  select(input: SelectInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.select(input)));
  }

  cancel(input: CancelInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.cancel(input)));
  }

  opsCancel(
    input: OpsCancelInput,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsInterveneResult> {
    return this.run(() => {
      const ride = finish(this.ledger.opsCancel(input));
      return { ride, auditId: `memory-audit-${ride.id}-cancel` };
    });
  }

  opsReassign(
    input: OpsReassignInput,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsInterveneResult> {
    return this.run(() => {
      const ride = finish(this.ledger.opsReassign(input));
      return { ride, auditId: `memory-audit-${ride.id}-reassign` };
    });
  }

  markEnRoute(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.markEnRoute(input)));
  }

  markArrived(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.markArrived(input)));
  }

  startTrip(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.startTrip(input)));
  }

  complete(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.complete(input)));
  }

  expireDue(now: Date, limit?: number): Promise<string[]> {
    return this.run(() => {
      const expired = this.ledger.expireDue(now);
      if (limit !== undefined && limit > 0) {
        return expired.slice(0, limit);
      }
      return expired;
    });
  }

  private run<T>(work: () => T): Promise<T> {
    const execute = this.tail.then(() => work());
    this.tail = execute.then(
      () => undefined,
      () => undefined,
    );
    return execute;
  }
}

function finish(outcome: { error?: RideRuleError['code']; ride?: RideSnapshot }): RideSnapshot {
  if (outcome.error || !outcome.ride) {
    throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
  }
  return outcome.ride;
}
