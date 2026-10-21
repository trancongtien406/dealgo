import { Inject, Injectable, Optional } from '@nestjs/common';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { authError } from '../identity/auth-error.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import {
  DEFAULT_NOTIFICATION_PREFS,
  prefsAllow,
  type NotificationPrefs,
} from './notification-prefs.js';

export type SessionView = {
  id: string;
  channel: string;
  deviceLabel: string | null;
  userAgent: string | null;
  ipAddress: string | null;
  current: boolean;
  createdAt: string;
  lastSeenAt: string;
};

type PrefRow = NotificationPrefs & { userId: string };

@Injectable()
export class AccountSettingsService {
  private readonly memoryPrefs = new Map<string, PrefRow>();

  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly passwords: PasswordHasher,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

  async getNotificationPrefs(userId: string): Promise<NotificationPrefs> {
    const row = await this.readPrefs(userId);
    return row ?? { ...DEFAULT_NOTIFICATION_PREFS };
  }

  async updateNotificationPrefs(
    userId: string,
    patch: Partial<NotificationPrefs>,
  ): Promise<NotificationPrefs> {
    const current = await this.getNotificationPrefs(userId);
    const next: NotificationPrefs = {
      ride: patch.ride ?? current.ride,
      food: patch.food ?? current.food,
      chat: patch.chat ?? current.chat,
      promotion: patch.promotion ?? current.promotion,
      news: patch.news ?? current.news,
    };
    await this.writePrefs(userId, next);
    return next;
  }

  /** Drop recipients who opted out of this inbox/push category. */
  async filterRecipients(userIds: string[], category: string): Promise<string[]> {
    if (userIds.length === 0) return [];
    const allowed: string[] = [];
    for (const userId of userIds) {
      const prefs = await this.getNotificationPrefs(userId);
      if (prefsAllow(prefs, category)) {
        allowed.push(userId);
      }
    }
    return allowed;
  }

  async listSessions(userId: string, currentSessionId: string): Promise<SessionView[]> {
    const rows = await this.identity.listActiveSessions(userId);
    return rows
      .map((row) => ({
        id: row.id,
        channel: row.channel,
        deviceLabel: row.deviceLabel,
        userAgent: row.userAgent,
        ipAddress: row.ipAddress,
        current: row.id === currentSessionId,
        createdAt: row.createdAt.toISOString(),
        lastSeenAt: row.lastSeenAt.toISOString(),
      }))
      .sort((a, b) => {
        if (a.current !== b.current) return a.current ? -1 : 1;
        return b.lastSeenAt.localeCompare(a.lastSeenAt);
      });
  }

  async revokeSession(
    userId: string,
    sessionId: string,
    currentSessionId: string,
  ): Promise<{ revoked: true }> {
    if (sessionId === currentSessionId) {
      throw authError(400, 'SESSION_IS_CURRENT', 'Use sign-out to leave this device');
    }
    const rows = await this.identity.listActiveSessions(userId);
    const target = rows.find((row) => row.id === sessionId);
    if (!target) {
      throw authError(404, 'SESSION_NOT_FOUND', 'Session not found');
    }
    await this.identity.revokeSession(sessionId, 'USER', new Date());
    return { revoked: true };
  }

  async revokeOtherSessions(
    userId: string,
    currentSessionId: string,
  ): Promise<{ revoked: number }> {
    return {
      revoked: await this.identity.revokeOtherSessions(userId, currentSessionId, new Date()),
    };
  }

  async changePassword(
    userId: string,
    currentSessionId: string,
    currentPassword: string,
    newPassword: string,
  ): Promise<{ changed: true; revokedOthers: number }> {
    if (currentPassword === newPassword) {
      throw authError(400, 'PASSWORD_UNCHANGED', 'New password must differ from the current one');
    }
    const credential = await this.identity.findCustomerCredential(userId);
    if (!credential) {
      throw authError(409, 'PASSWORD_NOT_SET', 'This account has no password login');
    }
    const ok = await this.passwords.verify(credential.passwordHash, currentPassword);
    if (!ok) {
      throw authError(401, 'AUTH_PASSWORD_INVALID', 'Current password is incorrect');
    }
    await this.identity.saveCustomerCredential(userId, await this.passwords.hash(newPassword));
    const revokedOthers = await this.identity.revokeOtherSessions(
      userId,
      currentSessionId,
      new Date(),
    );
    return { changed: true, revokedOthers };
  }

  async touchCurrentDevice(
    sessionId: string,
    meta: { deviceLabel?: string | null; userAgent?: string | null; ipAddress?: string | null },
  ): Promise<{ updated: true }> {
    await this.identity.touchSessionMeta(sessionId, meta, new Date());
    return { updated: true };
  }

  private async readPrefs(userId: string): Promise<NotificationPrefs | null> {
    const db = this.prisma?.db();
    if (!db) {
      const row = this.memoryPrefs.get(userId);
      return row ? { ...row } : null;
    }
    const row = await db.userNotificationPreference.findUnique({ where: { userId } });
    if (!row) return null;
    return {
      ride: row.ride,
      food: row.food,
      chat: row.chat,
      promotion: row.promotion,
      news: row.news,
    };
  }

  private async writePrefs(userId: string, prefs: NotificationPrefs): Promise<void> {
    const db = this.prisma?.db();
    if (!db) {
      this.memoryPrefs.set(userId, { userId, ...prefs });
      return;
    }
    await db.userNotificationPreference.upsert({
      where: { userId },
      create: { userId, ...prefs },
      update: { ...prefs },
    });
  }
}
