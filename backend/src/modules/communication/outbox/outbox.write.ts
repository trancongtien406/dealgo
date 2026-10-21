import { Prisma } from '../../../generated/prisma/client.js';

export type OutboxAggregateType = 'Ride' | 'FoodOrder' | 'NotificationCampaign';

export type StatusOutboxAggregateType = 'Ride' | 'FoodOrder';

export type OutboxWriteInput = {
  aggregateType: StatusOutboxAggregateType;
  aggregateId: string;
  status: string;
  payload?: Record<string, unknown>;
};

const RIDE_OUTBOX_STATUSES = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
  'COMPLETED',
  'CANCELLED',
  'EXPIRED',
]);

const FOOD_OUTBOX_STATUSES = new Set([
  'PLACED',
  'PREPARING',
  'READY',
  'ASSIGNED',
  'PICKED_UP',
  'DELIVERED',
  'FAILED',
  'CANCELLED',
]);

type OutboxTx = {
  outboxMessage: {
    createMany: (args: {
      data: Array<{
        eventKey: string;
        aggregateType: string;
        aggregateId: string;
        eventType: string;
        payload: Prisma.InputJsonValue;
      }>;
      skipDuplicates?: boolean;
    }) => Promise<{ count: number }>;
  };
};

export function shouldEmitRideStatus(status: string): boolean {
  return RIDE_OUTBOX_STATUSES.has(status);
}

export function shouldEmitFoodStatus(status: string): boolean {
  return FOOD_OUTBOX_STATUSES.has(status);
}

export function outboxEventKey(
  aggregateType: StatusOutboxAggregateType,
  aggregateId: string,
  status: string,
): string {
  return `${aggregateType}:${aggregateId}:status:${status}`;
}

export function outboxEventType(
  aggregateType: StatusOutboxAggregateType,
  status: string,
): string {
  return `${aggregateType}.status.${status}`;
}

/**
 * Writes an outbox row inside the caller's transaction.
 * Uses ON CONFLICT DO NOTHING (skipDuplicates) so a duplicate eventKey does not
 * abort the PostgreSQL transaction — catching P2002 after create() still leaves
 * the TX aborted and rolls back domain updates (e.g. ride EXPIRED).
 */
export async function writeStatusOutbox(
  tx: OutboxTx,
  input: OutboxWriteInput,
): Promise<'written' | 'skipped' | 'duplicate'> {
  const notable =
    input.aggregateType === 'Ride'
      ? shouldEmitRideStatus(input.status)
      : shouldEmitFoodStatus(input.status);
  if (!notable) {
    return 'skipped';
  }

  const eventKey = outboxEventKey(input.aggregateType, input.aggregateId, input.status);
  const eventType = outboxEventType(input.aggregateType, input.status);
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey,
        aggregateType: input.aggregateType,
        aggregateId: input.aggregateId,
        eventType,
        payload: {
          status: input.status,
          ...input.payload,
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}

export type OpsOutboxWriteInput = {
  aggregateType: StatusOutboxAggregateType;
  aggregateId: string;
  action: 'cancel' | 'reassign';
  auditId: string;
  status: string;
  payload?: Record<string, unknown>;
};

/** Ops intervention outbox row; eventKey includes auditId for uniqueness. */
export async function writeOpsActionOutbox(
  tx: OutboxTx,
  input: OpsOutboxWriteInput,
): Promise<'written' | 'duplicate'> {
  const eventKey = `${input.aggregateType}:${input.aggregateId}:ops:${input.action}:${input.auditId}`;
  const eventType = `${input.aggregateType}.ops.${input.action}`;
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey,
        aggregateType: input.aggregateType,
        aggregateId: input.aggregateId,
        eventType,
        payload: {
          status: input.status,
          auditId: input.auditId,
          ...input.payload,
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}

export type CampaignOutboxWriteInput = {
  campaignId: string;
  code: string;
  title: string;
  body: string;
  audience: string;
  channels: string[];
};

/** Best-effort push fan-out for approved campaigns that include PUSH. */
export async function writeCampaignSendOutbox(
  tx: OutboxTx,
  input: CampaignOutboxWriteInput,
): Promise<'written' | 'duplicate'> {
  const eventKey = `NotificationCampaign:${input.campaignId}:send`;
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey,
        aggregateType: 'NotificationCampaign',
        aggregateId: input.campaignId,
        eventType: 'NotificationCampaign.send',
        payload: {
          status: 'SENDING',
          code: input.code,
          title: input.title,
          body: input.body,
          audience: input.audience,
          channels: input.channels,
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}
