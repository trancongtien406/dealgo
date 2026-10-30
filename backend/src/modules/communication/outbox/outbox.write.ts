import { Prisma } from '../../../generated/prisma/client.js';

export type OutboxAggregateType =
  | 'Ride'
  | 'FoodOrder'
  | 'NotificationCampaign'
  | 'PartnerApplication';

export type StatusOutboxAggregateType = 'Ride' | 'FoodOrder';

export type OutboxWriteInput = {
  aggregateType: StatusOutboxAggregateType;
  aggregateId: string;
  status: string;
  payload?: Record<string, unknown>;
  /**
   * Appended to the event key. A ride can be ASSIGNED again after a timeout/drop, so the
   * pre-trip statuses carry the driver + moment; otherwise the second "Khách đã chọn bạn"
   * would collide with the first key and be skipped.
   */
  eventKeySuffix?: string;
};

/** eventType of the row telling a dropped driver (and the customer) a ride went back to offers. */
export const RIDE_UNASSIGNED_EVENT = 'Ride.driver.unassigned';

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

  const baseKey = outboxEventKey(input.aggregateType, input.aggregateId, input.status);
  const eventKey = input.eventKeySuffix ? `${baseKey}:${input.eventKeySuffix}` : baseKey;
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

export type PartnerStatusOutboxInput = {
  applicationId: string;
  userId: string;
  role: string;
  status: 'IN_REVIEW' | 'APPROVED' | 'REJECTED';
  /** t61u: rejection reason / flagged sections for the applicant's realtime event. */
  reason?: string | null;
  sections?: string[];
  reviewedAt: Date;
};

/**
 * Partner decision event for the applicant's `user:` room. eventKey includes reviewedAt
 * because a rejected application can be resubmitted and reviewed again.
 */
export async function writePartnerStatusOutbox(
  tx: OutboxTx,
  input: PartnerStatusOutboxInput,
): Promise<'written' | 'duplicate'> {
  const eventKey = `PartnerApplication:${input.applicationId}:status:${input.status}:${input.reviewedAt.getTime()}`;
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey,
        aggregateType: 'PartnerApplication',
        aggregateId: input.applicationId,
        eventType: `PartnerApplication.status.${input.status}`,
        payload: {
          status: input.status,
          userId: input.userId,
          role: input.role,
          ...(input.reason ? { reason: input.reason } : {}),
          ...(input.sections?.length ? { sections: input.sections } : {}),
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}

/** Merchant edit of a food order (PENDING → customer, ACCEPTED → store). */
export const FOOD_CHANGE_EVENT_PREFIX = 'FoodOrder.change.';

export type FoodChangeOutboxInput = {
  orderId: string;
  changeId: string;
  changeStatus: 'PENDING' | 'ACCEPTED';
  /** Current order status (snapshot consumers need it). */
  status: string;
  storeId: string;
  expiresAt?: string;
};

export async function writeFoodChangeOutbox(
  tx: OutboxTx,
  input: FoodChangeOutboxInput,
): Promise<'written' | 'duplicate'> {
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey: `FoodOrder:${input.orderId}:change:${input.changeId}:${input.changeStatus}`,
        aggregateType: 'FoodOrder',
        aggregateId: input.orderId,
        eventType: `${FOOD_CHANGE_EVENT_PREFIX}${input.changeStatus}`,
        payload: {
          status: input.status,
          storeId: input.storeId,
          changeId: input.changeId,
          changeStatus: input.changeStatus,
          ...(input.expiresAt ? { expiresAt: input.expiresAt } : {}),
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}

export type RideUnassignedOutboxInput = {
  rideId: string;
  driverId: string;
  actor: string;
  reasonCode: string;
  fromStatus: string;
  at: Date;
};

/**
 * The assigned driver lost the ride (start/approach timeout, own drop, ops reassign). One row per
 * drop: the relay pushes + socket-hints the dropped driver (their app clears the job) and tells
 * the customer the ride is open for offers again.
 */
export async function writeRideUnassignedOutbox(
  tx: OutboxTx,
  input: RideUnassignedOutboxInput,
): Promise<'written' | 'duplicate'> {
  const result = await tx.outboxMessage.createMany({
    data: [
      {
        eventKey: `Ride:${input.rideId}:unassigned:${input.driverId}:${input.at.getTime()}`,
        aggregateType: 'Ride',
        aggregateId: input.rideId,
        eventType: RIDE_UNASSIGNED_EVENT,
        payload: {
          status: 'NEGOTIATING',
          droppedDriverId: input.driverId,
          actor: input.actor,
          reasonCode: input.reasonCode,
          fromStatus: input.fromStatus,
        } as Prisma.InputJsonValue,
      },
    ],
    skipDuplicates: true,
  });
  return result.count === 1 ? 'written' : 'duplicate';
}
