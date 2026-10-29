import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../../platform/config/env.js';
import { PrismaService } from '../../../platform/database/prisma.service.js';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import { chatCipherFromEnv, type ChatCipher } from './chat-cipher.js';
import { chatError } from './chat.error.js';
import { toView } from './chat-prisma.repository.js';

export type ChatReviewMessage = {
  id: string;
  senderUserId: string;
  senderName: string;
  senderRole: 'CUSTOMER' | 'PARTNER';
  /** Food: DRIVER (customer↔driver) or MERCHANT (customer↔shop) thread. */
  channel: string;
  body: string;
  createdAt: string;
};

export type ChatReviewResult = {
  threadId: string | null;
  kind: 'ride' | 'food';
  id: string;
  retentionDays: number;
  messages: ChatReviewMessage[];
};

export const CHAT_REVIEW_MAX_MESSAGES = 500;

/**
 * Ops chat review (DEC-PROD-056). Server-side decrypt of one ride/order thread, gated by the
 * `chat.review` permission at the controller. Every read writes ops_audit_logs
 * (CHAT_REVIEW / CHAT_THREAD) with the stated reason BEFORE content is returned.
 */
@Injectable()
export class ChatReviewService {
  private readonly logger = new Logger(ChatReviewService.name);
  private cipherCache: ChatCipher | null | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly settings: PlatformSettingsService,
  ) {}

  private cipher(): ChatCipher | null {
    if (this.cipherCache === undefined) {
      this.cipherCache = chatCipherFromEnv({
        NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
        CHAT_ENCRYPTION_KEY: this.config.get('CHAT_ENCRYPTION_KEY', { infer: true }),
        CHAT_ENCRYPTION_KEY_VERSION: this.config.get('CHAT_ENCRYPTION_KEY_VERSION', { infer: true }),
        CHAT_ENCRYPTION_PREVIOUS_KEYS: this.config.get('CHAT_ENCRYPTION_PREVIOUS_KEYS', { infer: true }),
      });
    }
    return this.cipherCache;
  }

  async review(
    input: { kind: 'ride' | 'food'; id: string; reason: string; ticketId?: string },
    actorUserId: string,
  ): Promise<ChatReviewResult> {
    const db = this.prisma.db();
    if (!db) {
      throw chatError('CHAT_UNAVAILABLE');
    }
    const owner =
      input.kind === 'ride'
        ? await db.ride.findUnique({ where: { id: input.id }, select: { customerId: true } })
        : await db.foodOrder.findUnique({ where: { id: input.id }, select: { customerId: true } });
    if (!owner) {
      throw chatError('CHAT_NOT_FOUND');
    }
    // A food order has a driver thread and a shop thread; ops reviews both, in time order.
    const threads = await db.chatThread.findMany({
      where: input.kind === 'ride' ? { rideId: input.id } : { foodOrderId: input.id },
      select: { id: true, channel: true },
      orderBy: { createdAt: 'asc' },
    });
    const thread = threads[0] ?? null;
    const channelOf = new Map(threads.map((t) => [t.id, t.channel]));

    await db.opsAuditLog.create({
      data: {
        actorUserId,
        action: 'CHAT_REVIEW',
        entityType: 'CHAT_THREAD',
        entityId: thread?.id ?? input.id,
        reason: input.reason.trim(),
        metadata: {
          kind: input.kind,
          targetId: input.id,
          ticketId: input.ticketId ?? null,
          threadIds: threads.map((t) => t.id),
        },
      },
    });
    this.logger.warn({ msg: 'chat.review', actorUserId, kind: input.kind, targetId: input.id });

    const retentionDays = await this.settings.getNumber('CHAT_RETENTION_DAYS');
    if (!thread) {
      return { threadId: null, kind: input.kind, id: input.id, retentionDays, messages: [] };
    }
    const rows = await db.chatMessage.findMany({
      where: { threadId: { in: threads.map((t) => t.id) } },
      orderBy: { createdAt: 'asc' },
      take: CHAT_REVIEW_MAX_MESSAGES,
      include: { sender: { select: { displayName: true } } },
    });
    const cipher = this.cipher();
    return {
      threadId: thread.id,
      kind: input.kind,
      id: input.id,
      retentionDays,
      messages: rows.map((row) => {
        const view = toView(row, cipher);
        return {
          id: view.id,
          senderUserId: view.senderUserId,
          senderName: row.sender.displayName,
          senderRole: view.senderUserId === owner.customerId ? 'CUSTOMER' : 'PARTNER',
          channel: channelOf.get(view.threadId) ?? 'DRIVER',
          body: view.body,
          createdAt: view.createdAt.toISOString(),
        };
      }),
    };
  }
}
