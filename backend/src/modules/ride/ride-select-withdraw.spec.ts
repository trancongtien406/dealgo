/**
 * RIDE-003: selecting a driver withdraws that driver's PENDING offers on other rides in the
 * same transaction, and the caller hears about those rides only after commit.
 * Prisma is mocked; the Postgres race lives in test/concurrency/ride-select-withdraw.pg.spec.ts.
 */
import type { PrismaClient } from '../../generated/prisma/client.js';
import { PrismaRideRepository } from './ride-prisma.repository.js';
import type { SelectInput } from './ride-ledger.js';

type Offer = { id: string; rideId: string; driverId: string; status: string };

function harness(opts: { prior?: boolean; otherOffers?: Offer[]; failCommit?: boolean } = {}) {
  const events: string[] = [];
  const ride = { id: 'ride-1', customerId: 'c1', assignedDriverId: 'd1', agreedFareVnd: 30_000 };
  const tx = {
    rideSelection: { findUnique: vi.fn(async () => (opts.prior ? { rideId: 'ride-1' } : null)) },
    rideOffer: {
      findUnique: vi.fn(async () => ({ id: 'o1', rideId: 'ride-1', driverId: 'd1', status: 'PENDING' })),
      findMany: vi.fn(async () => opts.otherOffers ?? []),
      updateMany: vi.fn(async (args: unknown) => {
        events.push('withdraw');
        return { count: (opts.otherOffers ?? []).length, args };
      }),
    },
    ride: { count: vi.fn(async () => 0) },
    foodOrder: { count: vi.fn(async () => 0) },
    $executeRaw: vi.fn(async () => 0),
  };
  const db = {
    $transaction: vi.fn(async (fn: (t: typeof tx) => Promise<unknown>) => {
      const result = await fn(tx);
      if (opts.failCommit) throw new Error('commit failed');
      events.push('commit');
      return result;
    }),
  } as unknown as PrismaClient;
  const repo = new PrismaRideRepository(db);
  const internals = repo as unknown as Record<string, unknown>;
  internals.hydrateSelection = vi.fn(async () => ({ select: () => ({ ride }) }));
  internals.persist = vi.fn(async () => undefined);
  internals.selectionReplay = vi.fn(async () => (opts.prior ? ride : null));
  const onOffersWithdrawn = vi.fn((ids: string[]) => events.push(`notify:${ids.join(',')}`));
  const input: SelectInput = {
    rideId: 'ride-1',
    customerId: 'c1',
    offerId: 'o1',
    idempotencyKey: 'k1',
    now: new Date('2026-11-02T00:00:00Z'),
    onOffersWithdrawn,
  };
  return { repo, tx, input, events, onOffersWithdrawn };
}

describe('RIDE-003 select withdraws the winner\'s other offers', () => {
  it('withdraws PENDING offers on other rides in the transaction and notifies after commit', async () => {
    const h = harness({
      otherOffers: [
        { id: 'o2', rideId: 'ride-2', driverId: 'd1', status: 'PENDING' },
        { id: 'o3', rideId: 'ride-3', driverId: 'd1', status: 'PENDING' },
        { id: 'o4', rideId: 'ride-2', driverId: 'd1', status: 'PENDING' },
      ],
    });
    await h.repo.select(h.input);
    expect(h.tx.rideOffer.findMany).toHaveBeenCalledWith({
      where: { driverId: 'd1', status: 'PENDING', rideId: { not: 'ride-1' } },
      select: { id: true, rideId: true },
    });
    expect(h.tx.rideOffer.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['o2', 'o3', 'o4'] }, status: 'PENDING' },
      data: { status: 'WITHDRAWN' },
    });
    expect(h.onOffersWithdrawn).toHaveBeenCalledWith(['ride-2', 'ride-3']);
    expect(h.events).toEqual(['withdraw', 'commit', 'notify:ride-2,ride-3']);
  });

  it('does not update or notify when the driver has no other pending offers', async () => {
    const h = harness();
    await h.repo.select(h.input);
    expect(h.tx.rideOffer.updateMany).not.toHaveBeenCalled();
    expect(h.onOffersWithdrawn).not.toHaveBeenCalled();
  });

  it('a replayed selection (same idempotency key) withdraws nothing', async () => {
    const h = harness({ prior: true, otherOffers: [{ id: 'o2', rideId: 'ride-2', driverId: 'd1', status: 'PENDING' }] });
    await h.repo.select(h.input);
    expect(h.tx.rideOffer.findMany).not.toHaveBeenCalled();
    expect(h.onOffersWithdrawn).not.toHaveBeenCalled();
  });

  it('never notifies when the transaction does not commit', async () => {
    const h = harness({ failCommit: true, otherOffers: [{ id: 'o2', rideId: 'ride-2', driverId: 'd1', status: 'PENDING' }] });
    await expect(h.repo.select(h.input)).rejects.toThrow('commit failed');
    expect(h.onOffersWithdrawn).not.toHaveBeenCalled();
  });
});
