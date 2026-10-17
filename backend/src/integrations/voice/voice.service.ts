import { Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isWithinContactWindow } from '../../modules/communication/contact-window.js';
import type { AppEnv } from '../../platform/config/env.js';
import type { RequestActor } from '../../modules/identity/access-auth.guard.js';
import { FoodService } from '../../modules/food-order/food.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { RideService } from '../../modules/ride/ride.service.js';
import { VOICE_PORT, type VoiceAggregateType } from './voice.constants.js';
import { UnavailableVoiceError, type VoicePort, type VoiceSessionView } from './voice-port.js';
import { voiceError } from './voice.error.js';

@Injectable()
export class VoiceService {
  constructor(
    @Inject(VOICE_PORT) private readonly voice: VoicePort,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly settings: PlatformSettingsService,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

  async createForRide(actor: RequestActor, rideId: string): Promise<VoiceSessionView> {
    if (!(await this.rides.canSubscribe(actor.userId, rideId))) {
      throw voiceError('VOICE_FORBIDDEN');
    }
    const meta = await this.rides.contactMeta(rideId);
    if (!meta) {
      throw voiceError('VOICE_NOT_FOUND');
    }
    await this.assertWindow('ride', meta.status, meta.updatedAt);
    return this.createSession('Ride', rideId, actor.userId);
  }

  async createForFood(actor: RequestActor, orderId: string): Promise<VoiceSessionView> {
    if (!(await this.food.canSubscribe(actor.userId, orderId))) {
      throw voiceError('VOICE_FORBIDDEN');
    }
    const meta = await this.food.contactMeta(orderId);
    if (!meta) {
      throw voiceError('VOICE_NOT_FOUND');
    }
    await this.assertWindow('food', meta.status, meta.updatedAt);
    return this.createSession('FoodOrder', orderId, actor.userId);
  }

  private async assertWindow(kind: 'ride' | 'food', status: string, updatedAt: Date): Promise<void> {
    const windowMinutes = await this.settings.getNumber('CONTACT_WINDOW_MINUTES');
    const allowed = isWithinContactWindow({
      kind,
      status,
      updatedAt,
      now: new Date(),
      windowMinutes,
    });
    if (!allowed) {
      throw voiceError('VOICE_WINDOW_CLOSED');
    }
  }

  private async createSession(
    aggregateType: VoiceAggregateType,
    aggregateId: string,
    userId: string,
  ): Promise<VoiceSessionView> {
    let session: VoiceSessionView;
    try {
      session = await this.voice.createSession({ aggregateType, aggregateId, userId });
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
      // Audit is best-effort; session token was already issued.
    }
  }
}
