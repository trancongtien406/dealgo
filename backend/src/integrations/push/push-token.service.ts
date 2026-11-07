import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { VOIP_PUSH_PLATFORM } from './apns-voip-sender.js';

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
      // One device token = one app install = the account signed in there now.
      for (const [other, tokens] of this.memory) {
        if (other !== userId) tokens.delete(trimmed);
      }
      const byUser = this.memory.get(userId) ?? new Map<string, string>();
      byUser.set(trimmed, platform.slice(0, 32));
      this.memory.set(userId, byUser);
      return { registered: true };
    }
    // A device token belongs to one install: when another account signs in on that phone
    // (no clean logout), the previous owner must stop receiving pushes there.
    await db.$transaction([
      db.pushDeviceToken.deleteMany({
        where: { token: trimmed, userId: { not: userId } },
      }),
      db.pushDeviceToken.upsert({
        where: { userId_token: { userId, token: trimmed } },
        create: { userId, token: trimmed, platform: platform.slice(0, 32) },
        update: { platform: platform.slice(0, 32) },
      }),
    ]);
    return { registered: true };
  }

  /** Logout / permission revoked: forget this device token for the user (idempotent). */
  async unregister(
    userId: string,
    token: string,
  ): Promise<{ unregistered: true }> {
    const trimmed = token.trim();
    const db = this.prisma.db();
    if (!db) {
      this.memory.get(userId)?.delete(trimmed);
      return { unregistered: true };
    }
    await db.pushDeviceToken.deleteMany({ where: { userId, token: trimmed } });
    return { unregistered: true };
  }

  /** Forget all device tokens registered for a user (called on full sign-out or account deletion). */
  async unregisterAll(userId: string): Promise<{ unregistered: true }> {
    const db = this.prisma.db();
    if (!db) {
      this.memory.delete(userId);
      return { unregistered: true };
    }
    await db.pushDeviceToken.deleteMany({ where: { userId } });
    return { unregistered: true };
  }

  /** FCM says the token is dead (app uninstalled / token rotated): drop it for everyone. */
  async forget(token: string): Promise<void> {
    const db = this.prisma.db();
    if (!db) {
      for (const tokens of this.memory.values()) tokens.delete(token);
      return;
    }
    await db.pushDeviceToken.deleteMany({ where: { token } });
  }

  /** FCM registration tokens (everything except PushKit VoIP tokens and [skipPlatforms]). */
  async tokensForUser(
    userId: string,
    skipPlatforms: readonly string[] = [],
  ): Promise<string[]> {
    return this.tokensByKind(userId, false, skipPlatforms);
  }

  /** PushKit (VoIP) tokens: only incoming calls are sent there, through APNs directly. */
  async voipTokensForUser(userId: string): Promise<string[]> {
    return this.tokensByKind(userId, true);
  }

  private async tokensByKind(
    userId: string,
    voip: boolean,
    skipPlatforms: readonly string[] = [],
  ): Promise<string[]> {
    const db = this.prisma.db();
    if (!db) {
      return [...(this.memory.get(userId)?.entries() ?? [])]
        .filter(([, platform]) => (platform === VOIP_PUSH_PLATFORM) === voip)
        .filter(([, platform]) => !skipPlatforms.includes(platform))
        .map(([token]) => token);
    }
    // When the database session model is available, ensure the user has at least one active,
    // unexpired session before returning push tokens (a fully logged-out user receives no pushes).
    if (db.session?.findFirst) {
      const activeSession = await db.session.findFirst({
        where: {
          userId,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
        select: { id: true },
      });
      if (!activeSession) {
        return [];
      }
    }
    const rows = await db.pushDeviceToken.findMany({
      where: voip
        ? { userId, platform: VOIP_PUSH_PLATFORM }
        : {
            userId,
            platform: { notIn: [VOIP_PUSH_PLATFORM, ...skipPlatforms] },
          },
      select: { token: true },
    });
    return rows.map((row) => row.token);
  }
}
