export interface DomainEvent {
  readonly eventType: string;
  readonly aggregateId: string;
  readonly aggregateType: string;
  readonly occurredAt: Date;
  readonly payload: Record<string, unknown>;
}
