import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../platform/database/prisma.service.js';

@Injectable()
export class PushTokenService {
  private readonly memory = new Map<string, Map<string, string>>();

  constructor(private readonly prisma: PrismaService) {}

  async register(
    userId: string,
    token: string,
    platform = 'unknown',
  ): Promise<{ registered: true }> {
    const trimmed = token.trim();
    if (trimmed.length < 8 || trimmed.length > 512) {
      throw new Error('Invalid push token');
    }
    const db = this.prisma.db();
    if (!db) {
      const byUser = this.memory.get(userId) ?? new Map<string, string>();
      byUser.set(trimmed, platform.slice(0, 32));
      this.memory.set(userId, byUser);
      return { registered: true };
    }
    await db.pushDeviceToken.upsert({
      where: { userId_token: { userId, token: trimmed } },
      create: { userId, token: trimmed, platform: platform.slice(0, 32) },
      update: { platform: platform.slice(0, 32) },
    });
    return { registered: true };
  }

  async tokensForUser(userId: string): Promise<string[]> {
    const db = this.prisma.db();
    if (!db) {
      return [...(this.memory.get(userId)?.keys() ?? [])];
    }
    const rows = await db.pushDeviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    return rows.map((row) => row.token);
  }
}
