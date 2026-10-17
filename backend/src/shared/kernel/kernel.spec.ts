import { describe, expect, it } from 'vitest';
import { Result } from './result.js';
import { Entity } from './entity.js';
import { AggregateRoot } from './aggregate-root.js';
import type { DomainEvent } from './domain-event.js';
import { Money } from '../money/money.js';
import { paginate } from '../pagination/pagination.js';
import { NotFoundError, ConflictError } from '../errors/domain-error.js';

class TestEntity extends Entity<string> {}

class TestAggregate extends AggregateRoot<string> {
  createRide(): void {
    const event: DomainEvent = {
      eventType: 'ride.created',
      aggregateId: this.id,
      aggregateType: 'ride',
      occurredAt: new Date(),
      payload: { status: 'REQUESTED' },
    };
    this.addDomainEvent(event);
  }
}

describe('Shared Kernel & Domain Building Blocks', () => {
  it('Result ok and err works correctly', () => {
    const success = Result.ok({ id: '123' });
    expect(success.ok).toBe(true);
    if (success.ok) {
      expect(success.value.id).toBe('123');
    }

    const failure = Result.err(new Error('something bad'));
    expect(failure.ok).toBe(false);
    if (!failure.ok) {
      expect(failure.error.message).toBe('something bad');
    }
  });

  it('Entity equality is based on ID', () => {
    const e1 = new TestEntity('abc');
    const e2 = new TestEntity('abc');
    const e3 = new TestEntity('xyz');
    expect(e1.equals(e2)).toBe(true);
    expect(e1.equals(e3)).toBe(false);
    expect(e1.equals(null)).toBe(false);
  });

  it('AggregateRoot collects and clears domain events', () => {
    const aggregate = new TestAggregate('agg-1');
    expect(aggregate.domainEvents).toHaveLength(0);

    aggregate.createRide();
    expect(aggregate.domainEvents).toHaveLength(1);
    expect(aggregate.domainEvents[0].eventType).toBe('ride.created');

    aggregate.clearDomainEvents();
    expect(aggregate.domainEvents).toHaveLength(0);
  });

  it('Money handles calculations and formatting', () => {
    const m1 = Money.fromVnd(25000);
    const m2 = Money.fromVnd(15000);
    const sum = m1.add(m2);
    expect(sum.amount).toBe(40000);
    expect(sum.currency).toBe('VND');
    expect(sum.format()).toContain('40.000 VND');
  });

  it('Paginate creates structured page result', () => {
    const items = ['a', 'b', 'c'];
    const p = paginate(items, 10, 1, 3);
    expect(p.items).toEqual(items);
    expect(p.totalPages).toBe(4);
    expect(p.page).toBe(1);
  });

  it('Domain errors carry codes and names', () => {
    const nf = new NotFoundError('Ride', 'ride-999');
    expect(nf.code).toBe('NOT_FOUND');
    expect(nf.message).toContain('Ride not found: ride-999');

    const cf = new ConflictError('Order already taken');
    expect(cf.code).toBe('CONFLICT');
  });
});
