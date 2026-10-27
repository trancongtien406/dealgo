import { randomUUID } from 'node:crypto';
import type { VoiceAggregateType } from './voice.constants.js';

export type VoiceCallStatus = 'RINGING' | 'ACCEPTED' | 'DECLINED' | 'MISSED' | 'ENDED';
export type VoiceCallEndReason = 'NO_ANSWER' | 'CANCELLED' | 'HANGUP' | 'STALE';
export type VoiceCallRole = 'CUSTOMER' | 'DRIVER';

export const OPEN_CALL_STATUSES: readonly VoiceCallStatus[] = ['RINGING', 'ACCEPTED'];

export type VoiceCallRecord = {
  id: string;
  aggregateType: VoiceAggregateType;
  aggregateId: string;
  roomName: string;
  callerUserId: string;
  calleeUserId: string;
  callerRole: VoiceCallRole;
  status: VoiceCallStatus;
  ringUntil: Date;
  answeredAt: Date | null;
  endedAt: Date | null;
  endReason: VoiceCallEndReason | null;
  createdAt: Date;
};

export type NewVoiceCall = Omit<
  VoiceCallRecord,
  'id' | 'status' | 'answeredAt' | 'endedAt' | 'endReason' | 'createdAt'
> & { createdAt: Date };

export type VoiceCallPatch = {
  status: VoiceCallStatus;
  answeredAt?: Date;
  endedAt?: Date;
  endReason?: VoiceCallEndReason;
};

/** Raised when the trip already has a ringing / connected call. */
export class VoiceCallBusyError extends Error {
  constructor() {
    super('A call is already open for this transaction');
    this.name = 'VoiceCallBusyError';
  }
}

export interface VoiceCallRepository {
  /** Inserts a RINGING call; throws VoiceCallBusyError when the trip already has an open call. */
  create(input: NewVoiceCall): Promise<VoiceCallRecord>;
  findById(id: string): Promise<VoiceCallRecord | null>;
  findOpen(aggregateType: VoiceAggregateType, aggregateId: string): Promise<VoiceCallRecord | null>;
  /**
   * Compare-and-set: applies the patch only while the call is in one of `from`. Returns the
   * updated call, or null when another request (or node) already moved it on.
   */
  transition(id: string, from: readonly VoiceCallStatus[], patch: VoiceCallPatch): Promise<VoiceCallRecord | null>;
}

export class MemoryVoiceCallRepository implements VoiceCallRepository {
  private readonly calls = new Map<string, VoiceCallRecord>();

  async create(input: NewVoiceCall): Promise<VoiceCallRecord> {
    if (await this.findOpen(input.aggregateType, input.aggregateId)) {
      throw new VoiceCallBusyError();
    }
    const record: VoiceCallRecord = {
      ...input,
      id: randomUUID(),
      status: 'RINGING',
      answeredAt: null,
      endedAt: null,
      endReason: null,
    };
    this.calls.set(record.id, record);
    return { ...record };
  }

  async findById(id: string): Promise<VoiceCallRecord | null> {
    const call = this.calls.get(id);
    return call ? { ...call } : null;
  }

  async findOpen(aggregateType: VoiceAggregateType, aggregateId: string): Promise<VoiceCallRecord | null> {
    for (const call of this.calls.values()) {
      if (
        call.aggregateType === aggregateType &&
        call.aggregateId === aggregateId &&
        OPEN_CALL_STATUSES.includes(call.status)
      ) {
        return { ...call };
      }
    }
    return null;
  }

  async transition(
    id: string,
    from: readonly VoiceCallStatus[],
    patch: VoiceCallPatch,
  ): Promise<VoiceCallRecord | null> {
    const call = this.calls.get(id);
    if (!call || !from.includes(call.status)) {
      return null;
    }
    Object.assign(call, patch);
    return { ...call };
  }
}
