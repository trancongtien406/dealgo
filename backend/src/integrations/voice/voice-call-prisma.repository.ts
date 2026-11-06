import type { PrismaClient } from '../../generated/prisma/client.js';
import type { VoiceAggregateType } from './voice.constants.js';
import {
  OPEN_CALL_STATUSES,
  VoiceCallBusyError,
  type NewVoiceCall,
  type VoiceCallEndReason,
  type VoiceCallPatch,
  type VoiceCallRecord,
  type VoiceCallRepository,
  type VoiceCallRole,
  type VoiceCallStatus,
} from './voice-call.repository.js';

type VoiceCallRow = {
  id: string;
  aggregateType: string;
  aggregateId: string;
  roomName: string;
  callerUserId: string;
  calleeUserId: string;
  callerRole: string;
  status: string;
  ringUntil: Date;
  answeredAt: Date | null;
  endedAt: Date | null;
  endReason: string | null;
  createdAt: Date;
};

export class PrismaVoiceCallRepository implements VoiceCallRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(input: NewVoiceCall): Promise<VoiceCallRecord> {
    try {
      const row = await this.db.voiceCall.create({
        data: { ...input, status: 'RINGING' },
      });
      return toRecord(row);
    } catch (error) {
      // voice_calls_one_open_per_aggregate: the trip already has a ringing / connected call.
      if ((error as { code?: string }).code === 'P2002') {
        throw new VoiceCallBusyError();
      }
      throw error;
    }
  }

  async findById(id: string): Promise<VoiceCallRecord | null> {
    const row = await this.db.voiceCall.findUnique({ where: { id } });
    return row ? toRecord(row) : null;
  }

  async findOpen(aggregateType: VoiceAggregateType, aggregateId: string): Promise<VoiceCallRecord | null> {
    const row = await this.db.voiceCall.findFirst({
      where: { aggregateType, aggregateId, status: { in: [...OPEN_CALL_STATUSES] } },
      orderBy: { createdAt: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async findOpenForCallee(userId: string): Promise<VoiceCallRecord | null> {
    const row = await this.db.voiceCall.findFirst({
      where: {
        calleeUserId: userId,
        status: { in: [...OPEN_CALL_STATUSES] },
      },
      orderBy: { createdAt: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async transition(
    id: string,
    from: readonly VoiceCallStatus[],
    patch: VoiceCallPatch,
  ): Promise<VoiceCallRecord | null> {
    const result = await this.db.voiceCall.updateMany({
      where: { id, status: { in: [...from] } },
      data: patch,
    });
    if (result.count === 0) {
      return null;
    }
    return this.findById(id);
  }
}

function toRecord(row: VoiceCallRow): VoiceCallRecord {
  return {
    id: row.id,
    aggregateType: row.aggregateType as VoiceAggregateType,
    aggregateId: row.aggregateId,
    roomName: row.roomName,
    callerUserId: row.callerUserId,
    calleeUserId: row.calleeUserId,
    callerRole: row.callerRole as VoiceCallRole,
    status: row.status as VoiceCallStatus,
    ringUntil: row.ringUntil,
    answeredAt: row.answeredAt,
    endedAt: row.endedAt,
    endReason: row.endReason as VoiceCallEndReason | null,
    createdAt: row.createdAt,
  };
}
