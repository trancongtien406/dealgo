import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../platform/database/prisma.service.js';
import { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';

export const CHAT_RETENTION_BATCH = 5_000;
const DAY_MS = 86_400_000;

/**
 * Chat retention (DEC-PROD-056): deletes chat messages older than CHAT_RETENTION_DAYS (admin
 * setting, default 90). Threads stay attached to their ride/order; only message bodies go.
 */
@Injectable()
export class ChatRetentionService {
  private readonly logger = new Logger(ChatRetentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: PlatformSettingsService,
  ) {}

  async cutoff(now = new Date()): Promise<Date> {
    const days = await this.settings.getNumber('CHAT_RETENTION_DAYS');
    return new Date(now.getTime() - days * DAY_MS);
  }

  async runOnce(now = new Date()): Promise<number> {
    const db = this.prisma.db();
    if (!db) {
      return 0;
    }
    const before = await this.cutoff(now);
    let total = 0;
    for (;;) {
      const batch = await db.chatMessage.findMany({
        where: { createdAt: { lt: before } },
        select: { id: true },
        take: CHAT_RETENTION_BATCH,
      });
      if (batch.length === 0) {
        break;
      }
      const { count } = await db.chatMessage.deleteMany({ where: { id: { in: batch.map((row) => row.id) } } });
      total += count;
      if (batch.length < CHAT_RETENTION_BATCH) {
        break;
      }
    }
    if (total > 0) {
      this.logger.log({ msg: 'chat.retention_purged', deleted: total, before: before.toISOString() });
    }
    return total;
  }
}
