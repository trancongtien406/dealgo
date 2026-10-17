export const SNAPSHOT_EVENT = 'snapshot';

export const SUBSCRIBE_EVENT = 'subscribe';

export const UNSUBSCRIBE_EVENT = 'unsubscribe';

export type SnapshotRoomKind = 'ride' | 'food';

export type ParsedSnapshotRoom = {
  kind: SnapshotRoomKind;
  id: string;
  room: string;
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseSnapshotRoom(raw: string | undefined | null): ParsedSnapshotRoom | null {
  if (!raw || typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim();
  const match = /^(ride|food):(.+)$/.exec(trimmed);
  if (!match) {
    return null;
  }
  const kind = match[1] as SnapshotRoomKind;
  const id = match[2]?.trim() ?? '';
  if (!UUID_RE.test(id)) {
    return null;
  }
  return { kind, id, room: `${kind}:${id}` };
}

export function roomForAggregate(
  aggregateType: string,
  aggregateId: string,
): string | null {
  if (aggregateType === 'Ride') {
    return `ride:${aggregateId}`;
  }
  if (aggregateType === 'FoodOrder') {
    return `food:${aggregateId}`;
  }
  return null;
}

export type SnapshotEventPayload = {
  eventType: string;
  aggregateType: string;
  aggregateId: string;
  status: string;
  revision: string;
  occurredAt: string;
};
