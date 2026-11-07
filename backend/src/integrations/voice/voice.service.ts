import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccountSettingsService } from '../../modules/account-settings/account-settings.service.js';
import { ChatService } from '../../modules/communication/chat/chat.service.js';
import { isTerminalContactStatus } from '../../modules/communication/contact-window.js';
import { shortOrderCode } from '../../modules/communication/notification/notification-audience.js';
import {
  chatPushPathFor,
  pushPathFor,
} from '../../modules/communication/notification/push-path.js';
import { SnapshotFanoutService } from '../../modules/communication/realtime/snapshot-fanout.service.js';
import type { RequestActor } from '../../modules/identity/access-auth.guard.js';
import { FoodService } from '../../modules/food-order/food.service.js';
import { RideService } from '../../modules/ride/ride.service.js';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  VOIP_PUSH_SENDER,
  type VoipPushSender,
} from '../push/apns-voip-sender.js';
import { PUSH_SENDER } from '../push/push.constants.js';
import type { PushSender } from '../push/push-sender.js';
import {
  VOICE_CALL_MAX_SECONDS,
  VOICE_CALL_REPOSITORY,
  VOICE_CALL_RING_SECONDS,
  VOICE_MISSED_CALL_NOTE,
  VOICE_PORT,
  type VoiceAggregateType,
} from './voice.constants.js';
import {
  VoiceCallBusyError,
  type VoiceCallEndReason,
  type VoiceCallRecord,
  type VoiceCallRepository,
  type VoiceCallRole,
  type VoiceCallStatus,
} from './voice-call.repository.js';
import {
  roomNameFor,
  UnavailableVoiceError,
  type VoicePort,
  type VoiceSessionView,
} from './voice-port.js';
import { voiceError } from './voice.error.js';

export type VoiceCallView = {
  id: string;
  aggregateType: VoiceAggregateType;
  aggregateId: string;
  status: VoiceCallStatus;
  callerUserId: string;
  calleeUserId: string;
  callerRole: VoiceCallRole;
  ringUntil: string;
  answeredAt: string | null;
  endedAt: string | null;
  endReason: VoiceCallEndReason | null;
  createdAt: string;
};

/** Returned to the party who joins the LiveKit room (caller on start, callee on accept). */
export type VoiceCallJoinView = {
  call: VoiceCallView;
  session: VoiceSessionView;
};

export type VoiceCallConfigView = {
  /** Admin toggle VOICE_CALLS_ENABLED on and a voice provider configured. */
  enabled: boolean;
  ringSeconds: number;
};

type Parties = { customerId: string; driverId: string };

/**
 * In-app voice calls between a customer and the assigned driver of an active ride / food
 * order (DEC-PROD-007: audio only, never recorded).
 *
 * Flow: the caller starts a call (gets a LiveKit token and joins the trip room at once), the
 * callee gets a `call` socket event plus an urgent push and rings for VOICE_CALL_RING_SECONDS,
 * then accepts (gets a token) or declines. Nobody answering, or the caller hanging up first,
 * makes the call MISSED and leaves a note in the trip chat. State lives in `voice_calls` with
 * compare-and-set transitions, so any API node can serve any step.
 */
@Injectable()
export class VoiceService implements OnModuleDestroy {
  private readonly logger = new Logger(VoiceService.name);
  private readonly ringTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    @Inject(VOICE_PORT) private readonly voice: VoicePort,
    @Inject(VOICE_CALL_REPOSITORY) private readonly calls: VoiceCallRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly settings: PlatformSettingsService,
    @Optional() private readonly fanout?: SnapshotFanoutService,
    @Optional() private readonly chat?: ChatService,
    @Optional() @Inject(PUSH_SENDER) private readonly push?: PushSender,
    @Optional() private readonly prefs?: AccountSettingsService,
    @Optional() private readonly prisma?: PrismaService,
    @Optional()
    @Inject(VOIP_PUSH_SENDER)
    private readonly voip?: VoipPushSender,
  ) {}

  onModuleDestroy(): void {
    for (const timer of this.ringTimers.values()) {
      clearTimeout(timer);
    }
    this.ringTimers.clear();
  }

  async callConfig(): Promise<VoiceCallConfigView> {
    const enabled =
      this.voice.available &&
      (await this.settings.getBoolean('VOICE_CALLS_ENABLED'));
    return { enabled, ringSeconds: VOICE_CALL_RING_SECONDS };
  }

  startForRide(
    actor: RequestActor,
    rideId: string,
  ): Promise<VoiceCallJoinView> {
    return this.start(actor, 'Ride', rideId);
  }

  startForFood(
    actor: RequestActor,
    orderId: string,
  ): Promise<VoiceCallJoinView> {
    return this.start(actor, 'FoodOrder', orderId);
  }

  async get(actor: RequestActor, callId: string): Promise<VoiceCallView> {
    const call = await this.loadForParticipant(actor.userId, callId);
    return toView(await this.expireIfDue(call));
  }

  async accept(
    actor: RequestActor,
    callId: string,
  ): Promise<VoiceCallJoinView> {
    const call = await this.expireIfDue(
      await this.loadForParticipant(actor.userId, callId),
    );
    if (call.calleeUserId !== actor.userId) {
      throw voiceError('VOICE_FORBIDDEN');
    }
    if (call.status !== 'RINGING') {
      throw voiceError('VOICE_CALL_NOT_RINGING');
    }
    // The trip may have ended while the phone was ringing.
    await this.assertActiveParties(
      call.aggregateType,
      call.aggregateId,
      actor.userId,
    );
    const session = await this.issueSession(
      call.aggregateType,
      call.aggregateId,
      actor.userId,
    );
    const accepted = await this.calls.transition(call.id, ['RINGING'], {
      status: 'ACCEPTED',
      answeredAt: new Date(),
    });
    if (!accepted) {
      throw voiceError('VOICE_CALL_NOT_RINGING');
    }
    this.clearRingTimer(call.id);
    this.emit(accepted);
    return { call: toView(accepted), session };
  }

  async decline(actor: RequestActor, callId: string): Promise<VoiceCallView> {
    const call = await this.expireIfDue(
      await this.loadForParticipant(actor.userId, callId),
    );
    if (call.calleeUserId !== actor.userId) {
      throw voiceError('VOICE_FORBIDDEN');
    }
    if (call.status !== 'RINGING') {
      return toView(call);
    }
    const declined = await this.calls.transition(call.id, ['RINGING'], {
      status: 'DECLINED',
      endedAt: new Date(),
      endReason: 'HANGUP',
    });
    if (!declined) {
      return toView((await this.calls.findById(call.id)) ?? call);
    }
    this.clearRingTimer(call.id);
    this.emit(declined);
    await this.pushDismissAndroid(declined);
    return toView(declined);
  }

  /** Hang up: the caller cancelling while it rings makes it MISSED; a connected call ENDS. */
  async end(actor: RequestActor, callId: string): Promise<VoiceCallView> {
    const call = await this.expireIfDue(
      await this.loadForParticipant(actor.userId, callId),
    );
    if (call.status === 'RINGING') {
      if (call.calleeUserId === actor.userId) {
        return this.decline(actor, callId);
      }
      const missed = await this.finishMissed(call.id, 'CANCELLED');
      return toView(missed ?? (await this.calls.findById(call.id)) ?? call);
    }
    if (call.status !== 'ACCEPTED') {
      return toView(call);
    }
    const ended = await this.calls.transition(call.id, ['ACCEPTED'], {
      status: 'ENDED',
      endedAt: new Date(),
      endReason: 'HANGUP',
    });
    if (!ended) {
      return toView((await this.calls.findById(call.id)) ?? call);
    }
    this.emit(ended);
    return toView(ended);
  }

  private async start(
    actor: RequestActor,
    aggregateType: VoiceAggregateType,
    aggregateId: string,
  ): Promise<VoiceCallJoinView> {
    if (!(await this.settings.getBoolean('VOICE_CALLS_ENABLED'))) {
      throw voiceError('VOICE_DISABLED');
    }
    if (!this.voice.available) {
      throw voiceError('VOICE_UNAVAILABLE');
    }
    const parties = await this.assertActiveParties(
      aggregateType,
      aggregateId,
      actor.userId,
    );
    const callerRole: VoiceCallRole =
      parties.customerId === actor.userId ? 'CUSTOMER' : 'DRIVER';
    const calleeUserId =
      callerRole === 'CUSTOMER' ? parties.driverId : parties.customerId;

    const open = await this.calls.findOpen(aggregateType, aggregateId);
    if (open) {
      // A previous call whose ring window already passed is closed here and does not block.
      const current = await this.expireIfDue(open);
      if (current.status === 'RINGING' || current.status === 'ACCEPTED') {
        throw voiceError('VOICE_BUSY');
      }
    }
    // One phone, one call screen: a callee still ringing (or talking) on another ride/order
    // would get a second call screen that can neither be answered nor tracked.
    const calleeBusy = await this.calls.findOpenForCallee(calleeUserId);
    if (calleeBusy) {
      const current = await this.expireIfDue(calleeBusy);
      if (current.status === 'RINGING' || current.status === 'ACCEPTED') {
        throw voiceError('VOICE_BUSY');
      }
    }

    const session = await this.issueSession(
      aggregateType,
      aggregateId,
      actor.userId,
    );
    const now = new Date();
    let call: VoiceCallRecord;
    try {
      call = await this.calls.create({
        aggregateType,
        aggregateId,
        roomName: roomNameFor(aggregateType, aggregateId),
        callerUserId: actor.userId,
        calleeUserId,
        callerRole,
        ringUntil: new Date(now.getTime() + VOICE_CALL_RING_SECONDS * 1000),
        createdAt: now,
      });
    } catch (error) {
      if (error instanceof VoiceCallBusyError) {
        throw voiceError('VOICE_BUSY');
      }
      throw error;
    }
    this.scheduleRingTimeout(call);
    this.emit(call);
    await this.pushIncoming(call);
    return { call: toView(call), session };
  }

  /**
   * Customer ↔ assigned driver only, while the ride / order is still running. A terminal trip
   * (completed, cancelled, delivered…) cannot be called even inside the chat contact window.
   */
  private async assertActiveParties(
    aggregateType: VoiceAggregateType,
    aggregateId: string,
    userId: string,
  ): Promise<Parties> {
    const roles =
      aggregateType === 'Ride'
        ? await this.rides.participantRoles(aggregateId)
        : await this.food.participantRoles(aggregateId);
    const meta =
      aggregateType === 'Ride'
        ? await this.rides.contactMeta(aggregateId)
        : await this.food.contactMeta(aggregateId);
    if (!roles || !meta) {
      throw voiceError('VOICE_NOT_FOUND');
    }
    if (userId !== roles.customerId && userId !== roles.driverId) {
      throw voiceError('VOICE_FORBIDDEN');
    }
    if (
      isTerminalContactStatus(
        aggregateType === 'Ride' ? 'ride' : 'food',
        meta.status,
      )
    ) {
      throw voiceError('VOICE_WINDOW_CLOSED');
    }
    if (!roles.driverId) {
      throw voiceError('VOICE_NO_COUNTERPART');
    }
    return { customerId: roles.customerId, driverId: roles.driverId };
  }

  private async loadForParticipant(
    userId: string,
    callId: string,
  ): Promise<VoiceCallRecord> {
    const call = await this.calls.findById(callId);
    if (
      !call ||
      (call.callerUserId !== userId && call.calleeUserId !== userId)
    ) {
      // Same answer for "missing" and "not yours": call ids are not discoverable.
      throw voiceError('VOICE_CALL_NOT_FOUND');
    }
    return call;
  }

  /** Lazily closes a call whose ring window passed (or a connected call left open for hours). */
  private async expireIfDue(call: VoiceCallRecord): Promise<VoiceCallRecord> {
    const now = Date.now();
    if (call.status === 'RINGING' && call.ringUntil.getTime() <= now) {
      return (
        (await this.finishMissed(call.id, 'NO_ANSWER')) ??
        (await this.calls.findById(call.id)) ??
        call
      );
    }
    if (
      call.status === 'ACCEPTED' &&
      (call.answeredAt ?? call.createdAt).getTime() +
        VOICE_CALL_MAX_SECONDS * 1000 <=
        now
    ) {
      const stale = await this.calls.transition(call.id, ['ACCEPTED'], {
        status: 'ENDED',
        endedAt: new Date(now),
        endReason: 'STALE',
      });
      if (stale) {
        this.emit(stale);
        return stale;
      }
      return (await this.calls.findById(call.id)) ?? call;
    }
    return call;
  }

  /**
   * RINGING → MISSED exactly once (compare-and-set), then tell both apps, leave the chat note
   * and push the callee. Returns null when another request already closed the call.
   */
  private async finishMissed(
    callId: string,
    reason: VoiceCallEndReason,
  ): Promise<VoiceCallRecord | null> {
    this.clearRingTimer(callId);
    const missed = await this.calls.transition(callId, ['RINGING'], {
      status: 'MISSED',
      endedAt: new Date(),
      endReason: reason,
    });
    if (!missed) {
      return null;
    }
    this.emit(missed);
    if (this.chat) {
      try {
        await this.chat.recordCallNote(
          missed.aggregateType,
          missed.aggregateId,
          missed.callerUserId,
          VOICE_MISSED_CALL_NOTE,
        );
      } catch (error) {
        this.logger.warn(
          `missed-call note failed for call ${shortOrderCode(callId)}: ${String(error)}`,
        );
      }
    }
    await this.pushDismissAndroid(missed);
    await this.pushMissed(missed);
    return missed;
  }

  private scheduleRingTimeout(call: VoiceCallRecord): void {
    const delay = Math.max(0, call.ringUntil.getTime() - Date.now());
    const timer = setTimeout(() => {
      this.ringTimers.delete(call.id);
      void this.finishMissed(call.id, 'NO_ANSWER').catch((error: unknown) => {
        this.logger.warn(
          `ring timeout failed for call ${shortOrderCode(call.id)}: ${String(error)}`,
        );
      });
    }, delay);
    timer.unref?.();
    this.ringTimers.set(call.id, timer);
  }

  private clearRingTimer(callId: string): void {
    const timer = this.ringTimers.get(callId);
    if (timer) {
      clearTimeout(timer);
      this.ringTimers.delete(callId);
    }
  }

  private emit(call: VoiceCallRecord): void {
    this.fanout?.emitCall({
      callId: call.id,
      aggregateType: call.aggregateType,
      aggregateId: call.aggregateId,
      status: call.status,
      callerUserId: call.callerUserId,
      calleeUserId: call.calleeUserId,
      callerRole: call.callerRole,
      ringUntil: call.ringUntil.toISOString(),
      endReason: call.endReason,
      occurredAt: new Date().toISOString(),
    });
  }

  /**
   * Urgent push so a phone with the app in the background rings (best effort). The app
   * turns it into the native call screen (Android ConnectionService UI); iOS gets a
   * PushKit push as well when the APNs VoIP key is configured, so CallKit rings.
   */
  private async pushIncoming(call: VoiceCallRecord): Promise<void> {
    const calleeRole = call.callerRole === 'CUSTOMER' ? 'DRIVER' : 'CUSTOMER';
    const from = call.callerRole === 'CUSTOMER' ? 'Khách' : 'Tài xế';
    const title = `${from} đang gọi cho bạn`;
    const body = `${call.aggregateType === 'Ride' ? 'Chuyến' : 'Đơn'} ${shortOrderCode(call.aggregateId)}: chạm để nghe máy.`;
    const data = {
      aggregateType: call.aggregateType,
      aggregateId: call.aggregateId,
      eventType: 'Call.incoming',
      callId: call.id,
      role: calleeRole,
      // The system call screen uses the server's ring window instead of guessing.
      // FCM data values are strings.
      ringSeconds: String(VOICE_CALL_RING_SECONDS),
      path:
        pushPathFor({
          aggregateType: call.aggregateType,
          aggregateId: call.aggregateId,
          role: calleeRole,
        }) ?? '',
    };
    // Dedupe: PushKit first. When CallKit rings on an iPhone, the FCM copy skips iOS
    // tokens, so the phone rings once (no extra "đang gọi" banner + sound).
    let voipDelivered = 0;
    if (this.voip?.enabled) {
      try {
        voipDelivered = await this.voip.sendIncomingCall({
          userId: call.calleeUserId,
          callId: call.id,
          title,
          body,
          ringSeconds: VOICE_CALL_RING_SECONDS,
          data,
        });
      } catch (error) {
        this.logger.warn(
          `incoming-call VoIP push failed for call ${shortOrderCode(call.id)}: ${String(error)}`,
        );
      }
    }
    if (this.push) {
      try {
        await this.push.send({
          userId: call.calleeUserId,
          title,
          body,
          data,
          collapseKey: `call-${call.id}`,
          ttlSeconds: VOICE_CALL_RING_SECONDS,
          urgent: true,
          // Android: data-only so only the native call screen shows (no duplicate tray copy).
          androidDataOnly: true,
          ...(voipDelivered > 0 ? { skipPlatforms: ['ios'] } : {}),
        });
      } catch (error) {
        this.logger.warn(
          `incoming-call push failed for call ${shortOrderCode(call.id)}: ${String(error)}`,
        );
      }
    }
  }

  /**
   * Data-only Android push so `firebaseMessagingBackgroundHandler` runs even when the app
   * is backgrounded or killed (an FCM push with a top-level `notification` block such as
   * `Call.missed` is handled by the system tray and never wakes the background isolate).
   */
  private async pushDismissAndroid(call: VoiceCallRecord): Promise<void> {
    if (!this.push) {
      return;
    }
    try {
      await this.push.send({
        userId: call.calleeUserId,
        title: '',
        body: '',
        data: {
          aggregateType: call.aggregateType,
          aggregateId: call.aggregateId,
          eventType: 'Call.cancelled',
          callId: call.id,
        },
        collapseKey: `call-dismiss-${call.id}`,
        ttlSeconds: VOICE_CALL_RING_SECONDS,
        urgent: true,
        androidDataOnly: true,
        skipPlatforms: ['ios', 'web'],
      });
    } catch (error) {
      this.logger.warn(
        `android call-dismiss push failed for call ${shortOrderCode(call.id)}: ${String(error)}`,
      );
    }
  }

  /** Replaces the ringing notification with "missed call"; honours the chat preference. */
  private async pushMissed(call: VoiceCallRecord): Promise<void> {
    if (!this.push) {
      return;
    }
    try {
      if (
        this.prefs &&
        (await this.prefs.filterRecipients([call.calleeUserId], 'CHAT'))
          .length === 0
      ) {
        return;
      }
      const calleeRole = call.callerRole === 'CUSTOMER' ? 'DRIVER' : 'CUSTOMER';
      const from = call.callerRole === 'CUSTOMER' ? 'khách' : 'tài xế';
      await this.push.send({
        userId: call.calleeUserId,
        title: `Cuộc gọi nhỡ từ ${from}`,
        body: `${call.aggregateType === 'Ride' ? 'Chuyến' : 'Đơn'} ${shortOrderCode(call.aggregateId)}: mở ứng dụng để gọi lại.`,
        data: {
          aggregateType: call.aggregateType,
          aggregateId: call.aggregateId,
          eventType: 'Call.missed',
          callId: call.id,
          role: calleeRole,
          // land in the job's chat, where the missed-call note sits (`?chat=1`).
          path:
            chatPushPathFor({
              aggregateType: call.aggregateType,
              aggregateId: call.aggregateId,
              role: calleeRole,
            }) ?? '',
        },
        collapseKey: `call-${call.id}`,
      });
    } catch (error) {
      this.logger.warn(
        `missed-call push failed for call ${shortOrderCode(call.id)}: ${String(error)}`,
      );
    }
  }

  private async issueSession(
    aggregateType: VoiceAggregateType,
    aggregateId: string,
    userId: string,
  ): Promise<VoiceSessionView> {
    let session: VoiceSessionView;
    try {
      session = await this.voice.createSession({
        aggregateType,
        aggregateId,
        userId,
      });
    } catch (error) {
      if (error instanceof UnavailableVoiceError) {
        throw voiceError('VOICE_UNAVAILABLE');
      }
      throw error;
    }
    await this.auditBestEffort({
      aggregateType,
      aggregateId,
      userId,
      roomName: session.roomName,
      provider: this.config.get('VOICE_PROVIDER', { infer: true }) ?? 'unknown',
      expiresAt: new Date(session.expiresAt),
    });
    return session;
  }

  private async auditBestEffort(input: {
    aggregateType: VoiceAggregateType;
    aggregateId: string;
    userId: string;
    roomName: string;
    provider: string;
    expiresAt: Date;
  }): Promise<void> {
    const db = this.prisma?.db();
    if (!db || !('voiceSession' in db)) {
      return;
    }
    try {
      await db.voiceSession.create({
        data: {
          aggregateType: input.aggregateType,
          aggregateId: input.aggregateId,
          userId: input.userId,
          roomName: input.roomName,
          provider: input.provider.slice(0, 32),
          expiresAt: input.expiresAt,
        },
      });
    } catch {
      // Audit is best-effort; the token was already issued.
    }
  }
}

function toView(call: VoiceCallRecord): VoiceCallView {
  return {
    id: call.id,
    aggregateType: call.aggregateType,
    aggregateId: call.aggregateId,
    status: call.status,
    callerUserId: call.callerUserId,
    calleeUserId: call.calleeUserId,
    callerRole: call.callerRole,
    ringUntil: call.ringUntil.toISOString(),
    answeredAt: call.answeredAt?.toISOString() ?? null,
    endedAt: call.endedAt?.toISOString() ?? null,
    endReason: call.endReason,
    createdAt: call.createdAt.toISOString(),
  };
}
