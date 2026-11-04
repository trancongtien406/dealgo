import { randomUUID } from 'node:crypto';
import { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import {
  UniqueConflictError,
  type DeviceRegistrationRecord,
  type EmailVerificationRecord,
  type GrantStatusName,
  type IdentityRepository,
  type NewSession,
  type OpsCredentialRecord,
  type OpsPasswordResetInput,
  type OpsRoleGrantListItem,
  type OpsUserDirectoryRecord,
  type OpsSuperAdminChangeInput,
  type OpsSuperAdminChangeResult,
  type OpsUserPage,
  type PasskeyCeremonyName,
  type PasskeyChallengeRecord,
  type PasskeyRecord,
  type EmailChallengePurpose,
  type EmailSignupChallengeRecord,
  type PasswordResetRecord,
  type PasswordResetReissueInput,
  type PhoneChallengeRecord,
  type RevokeReasonName,
  type RoleGrantRecord,
  type RoleName,
  type RotateResult,
  type SessionRecord,
  type StoredChannel,
  type UserGenderName,
  type UserProfilePatch,
  type UserRecord,
} from './identity.repository.js';

type DbUser = {
  id: string;
  email: string | null;
  phone: string | null;
  displayName: string;
  dateOfBirth: Date | null;
  gender: UserGenderName | null;
  avatarUrl: string | null;
  phoneVerifiedAt: Date | null;
  emailVerifiedAt: Date | null;
  contactPhone?: string | null;
  createdAt: Date;
  deletedAt: Date | null;
  purgeAfter: Date | null;
  purgedAt: Date | null;
};

export class PrismaIdentityRepository implements IdentityRepository {
  constructor(private readonly db: PrismaClient) {}

  async findUserById(id: string): Promise<UserRecord | null> {
    const user = await this.db.user.findUnique({ where: { id } });
    return user ? mapUser(user) : null;
  }

  async findUserByPhone(phone: string): Promise<UserRecord | null> {
    const user = await this.db.user.findUnique({ where: { phone } });
    return user ? mapUser(user) : null;
  }

  async findUserByEmail(email: string): Promise<UserRecord | null> {
    const user = await this.db.user.findUnique({ where: { email } });
    return user ? mapUser(user) : null;
  }

  async createUser(input: {
    email: string | null;
    phone: string | null;
    displayName: string;
    contactPhone?: string | null;
  }): Promise<UserRecord> {
    try {
      const user = await this.db.user.create({
        data: {
          email: input.email,
          phone: input.phone,
          displayName: input.displayName,
          ...(input.contactPhone !== undefined
            ? { contactPhone: input.contactPhone }
            : {}),
        },
      });
      return mapUser(user);
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async markPhoneVerified(userId: string, at: Date): Promise<UserRecord> {
    const user = await this.db.user.update({
      where: { id: userId },
      data: { phoneVerifiedAt: at },
    });
    return mapUser(user);
  }

  async setEmailVerified(userId: string, email: string, at: Date): Promise<UserRecord> {
    try {
      const user = await this.db.user.update({
        where: { id: userId },
        data: { email, emailVerifiedAt: at },
      });
      return mapUser(user);
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async updateUserProfile(userId: string, patch: UserProfilePatch): Promise<UserRecord> {
    const data: {
      displayName?: string;
      dateOfBirth?: Date | null;
      gender?: UserGenderName | null;
      avatarUrl?: string | null;
      contactPhone?: string | null;
    } = {};
    if (patch.contactPhone !== undefined) {
      data.contactPhone = patch.contactPhone;
    }
    if (patch.displayName !== undefined) {
      data.displayName = patch.displayName;
    }
    if (patch.dateOfBirth !== undefined) {
      data.dateOfBirth = patch.dateOfBirth;
    }
    if (patch.gender !== undefined) {
      data.gender = patch.gender;
    }
    if (patch.avatarUrl !== undefined) {
      data.avatarUrl = patch.avatarUrl;
    }
    const user = await this.db.user.update({
      where: { id: userId },
      data,
    });
    return mapUser(user);
  }

  async createPhoneChallenge(input: {
    userId: string | null;
    phone: string;
    codeHash: string;
    expiresAt: Date;
  }): Promise<PhoneChallengeRecord> {
    const challenge = await this.db.phoneChallenge.create({ data: input });
    return {
      id: challenge.id,
      userId: challenge.userId,
      phone: challenge.phone,
      codeHash: challenge.codeHash,
      expiresAt: challenge.expiresAt,
      attemptCount: challenge.attemptCount,
      consumedAt: challenge.consumedAt,
    };
  }

  async findPhoneChallenge(id: string): Promise<PhoneChallengeRecord | null> {
    const challenge = await this.db.phoneChallenge.findUnique({ where: { id } });
    if (!challenge) {
      return null;
    }
    return {
      id: challenge.id,
      userId: challenge.userId,
      phone: challenge.phone,
      codeHash: challenge.codeHash,
      expiresAt: challenge.expiresAt,
      attemptCount: challenge.attemptCount,
      consumedAt: challenge.consumedAt,
    };
  }

  async recordFailedPhoneAttempt(id: string): Promise<PhoneChallengeRecord> {
    const challenge = await this.db.phoneChallenge.update({
      where: { id },
      data: { attemptCount: { increment: 1 } },
    });
    return {
      id: challenge.id,
      userId: challenge.userId,
      phone: challenge.phone,
      codeHash: challenge.codeHash,
      expiresAt: challenge.expiresAt,
      attemptCount: challenge.attemptCount,
      consumedAt: challenge.consumedAt,
    };
  }

  async consumePhoneChallenge(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.phoneChallenge.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }

  async createEmailVerification(input: {
    userId: string;
    email: string;
    tokenHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<EmailVerificationRecord> {
    const { sentAt, ...rest } = input;
    const verification = await this.db.emailVerification.create({
      data: { ...rest, lastSentAt: sentAt, createdAt: sentAt },
    });
    return mapEmail(verification);
  }

  async findEmailVerification(id: string): Promise<EmailVerificationRecord | null> {
    const verification = await this.db.emailVerification.findUnique({ where: { id } });
    return verification ? mapEmail(verification) : null;
  }

  async findLatestEmailVerification(userId: string): Promise<EmailVerificationRecord | null> {
    const verification = await this.db.emailVerification.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return verification ? mapEmail(verification) : null;
  }

  async countEmailVerificationsSince(userId: string, since: Date): Promise<number> {
    return this.db.emailVerification.count({ where: { userId, createdAt: { gte: since } } });
  }

  async recordFailedEmailVerificationAttempt(id: string): Promise<EmailVerificationRecord> {
    const verification = await this.db.emailVerification.update({
      where: { id },
      data: { attemptCount: { increment: 1 } },
    });
    return mapEmail(verification);
  }

  async consumeEmailVerification(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.emailVerification.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }

  async createEmailSignupChallenge(input: {
    purpose?: EmailChallengePurpose;
    userId?: string | null;
    email: string;
    passwordHash: string | null;
    displayName: string;
    codeHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<EmailSignupChallengeRecord> {
    return this.db.emailSignupChallenge.create({
      data: {
        purpose: input.purpose ?? 'SIGNUP',
        userId: input.userId ?? null,
        email: input.email,
        passwordHash: input.passwordHash,
        displayName: input.displayName,
        codeHash: input.codeHash,
        expiresAt: input.expiresAt,
        lastSentAt: input.sentAt,
      },
    });
  }

  async findEmailSignupChallenge(id: string): Promise<EmailSignupChallengeRecord | null> {
    return this.db.emailSignupChallenge.findUnique({ where: { id } });
  }

  async findLatestEmailSignupChallenge(
    email: string,
  ): Promise<EmailSignupChallengeRecord | null> {
    return this.db.emailSignupChallenge.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
    });
  }

  async countEmailSignupChallengesSince(email: string, since: Date): Promise<number> {
    return this.db.emailSignupChallenge.count({
      where: { email, createdAt: { gte: since } },
    });
  }

  async recordFailedEmailSignupAttempt(id: string): Promise<EmailSignupChallengeRecord> {
    return this.db.emailSignupChallenge.update({
      where: { id },
      data: { attemptCount: { increment: 1 } },
    });
  }

  async reissueEmailSignupCode(
    id: string,
    input: {
      codeHash: string;
      expiresAt: Date;
      sentAt: Date;
      sentBefore: Date;
      maxSends: number;
      maxAttempts: number;
    },
  ): Promise<EmailSignupChallengeRecord | null> {
    // Conditional update so two concurrent resends cannot both pass the cooldown check,
    // and a locked challenge cannot be revived by a resend.
    const updated = await this.db.emailSignupChallenge.updateMany({
      where: {
        id,
        consumedAt: null,
        attemptCount: { lt: input.maxAttempts },
        lastSentAt: { lte: input.sentBefore },
        sendCount: { lt: input.maxSends },
      },
      data: {
        codeHash: input.codeHash,
        expiresAt: input.expiresAt,
        lastSentAt: input.sentAt,
        sendCount: { increment: 1 },
      },
    });
    if (updated.count !== 1) {
      return null;
    }
    return this.db.emailSignupChallenge.findUnique({ where: { id } });
  }

  async consumeEmailSignupChallenge(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.emailSignupChallenge.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }

  async createEmailPasswordUser(input: {
    email: string;
    displayName: string;
    passwordHash: string;
    verifiedAt: Date | null;
  }): Promise<UserRecord> {
    try {
      return await this.db.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            email: input.email,
            phone: null,
            displayName: input.displayName,
            emailVerifiedAt: input.verifiedAt,
          },
        });
        await tx.customerCredential.create({
          data: { userId: user.id, passwordHash: input.passwordHash },
        });
        await tx.roleGrant.create({
          data: { userId: user.id, role: 'CUSTOMER', status: 'ACTIVE' },
        });
        return mapUser(user);
      });
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async createPasswordReset(input: {
    userId: string | null;
    email: string;
    tokenHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<PasswordResetRecord> {
    const reset = await this.db.passwordReset.create({
      data: {
        userId: input.userId,
        email: input.email,
        tokenHash: input.tokenHash,
        expiresAt: input.expiresAt,
        lastSentAt: input.sentAt,
      },
    });
    return mapPasswordReset(reset);
  }

  async findPasswordReset(id: string): Promise<PasswordResetRecord | null> {
    const reset = await this.db.passwordReset.findUnique({ where: { id } });
    return reset ? mapPasswordReset(reset) : null;
  }

  async countPasswordResetsSince(email: string, since: Date): Promise<number> {
    return this.db.passwordReset.count({ where: { email, createdAt: { gte: since } } });
  }

  async recordFailedPasswordResetAttempt(id: string): Promise<PasswordResetRecord> {
    const reset = await this.db.passwordReset.update({
      where: { id },
      data: { attemptCount: { increment: 1 } },
    });
    return mapPasswordReset(reset);
  }

  async reissuePasswordResetCode(
    id: string,
    input: PasswordResetReissueInput,
  ): Promise<PasswordResetRecord | null> {
    // Conditional update: concurrent resends cannot both pass the cooldown, and a locked
    // challenge cannot be revived.
    const updated = await this.db.passwordReset.updateMany({
      where: {
        id,
        consumedAt: null,
        attemptCount: { lt: input.maxAttempts },
        lastSentAt: { lte: input.sentBefore },
        sendCount: { lt: input.maxSends },
      },
      data: {
        tokenHash: input.tokenHash,
        expiresAt: input.expiresAt,
        lastSentAt: input.sentAt,
        sendCount: { increment: 1 },
      },
    });
    if (updated.count !== 1) {
      return null;
    }
    const reset = await this.db.passwordReset.findUnique({ where: { id } });
    return reset ? mapPasswordReset(reset) : null;
  }

  async consumePasswordReset(id: string, at: Date, maxAttempts: number): Promise<boolean> {
    const updated = await this.db.passwordReset.updateMany({
      where: { id, consumedAt: null, attemptCount: { lt: maxAttempts } },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }

  async createSession(input: NewSession): Promise<SessionRecord> {
    const session = await this.db.session.create({
      data: {
        userId: input.userId,
        familyId: input.familyId,
        channel: input.channel,
        refreshTokenHash: input.refreshTokenHash,
        expiresAt: input.expiresAt,
        deviceId: input.deviceId ?? null,
        deviceLabel: input.deviceLabel ?? null,
        userAgent: input.userAgent ?? null,
        ipAddress: input.ipAddress ?? null,
      },
    });
    return mapSession(session);
  }

  async countRegistrationsByDeviceId(deviceId: string): Promise<number> {
    return this.db.deviceRegistration.count({
      where: { deviceId },
    });
  }

  async recordDeviceRegistration(input: {
    deviceId: string;
    userId: string;
    ipAddress?: string | null;
  }): Promise<DeviceRegistrationRecord> {
    const row = await this.db.deviceRegistration.create({
      data: {
        deviceId: input.deviceId,
        userId: input.userId,
        ipAddress: input.ipAddress ?? null,
      },
    });
    return {
      id: row.id,
      deviceId: row.deviceId,
      userId: row.userId,
      ipAddress: row.ipAddress,
      createdAt: row.createdAt,
    };
  }

  async listActiveSessions(userId: string): Promise<SessionRecord[]> {
    const rows = await this.db.session.findMany({
      where: { userId, revokedAt: null },
      orderBy: { lastSeenAt: 'desc' },
    });
    return rows.map(mapSession);
  }

  async revokeOtherSessions(userId: string, keepSessionId: string, at: Date): Promise<number> {
    const result = await this.db.session.updateMany({
      where: { userId, revokedAt: null, id: { not: keepSessionId } },
      data: { revokedAt: at, revokeReason: 'USER' },
    });
    return result.count;
  }

  async touchSessionMeta(
    id: string,
    meta: { deviceLabel?: string | null; userAgent?: string | null; ipAddress?: string | null },
    at: Date,
  ): Promise<void> {
    await this.db.session.updateMany({
      where: { id, revokedAt: null },
      data: {
        lastSeenAt: at,
        ...(meta.deviceLabel !== undefined ? { deviceLabel: meta.deviceLabel } : {}),
        ...(meta.userAgent !== undefined ? { userAgent: meta.userAgent } : {}),
        ...(meta.ipAddress !== undefined ? { ipAddress: meta.ipAddress } : {}),
      },
    });
  }

  async findSessionById(id: string): Promise<SessionRecord | null> {
    const session = await this.db.session.findUnique({ where: { id } });
    return session ? mapSession(session) : null;
  }

  async findSessionByRefreshTokenHash(refreshTokenHash: string): Promise<SessionRecord | null> {
    const session = await this.db.session.findUnique({ where: { refreshTokenHash } });
    return session ? mapSession(session) : null;
  }

  async rotateSession(
    refreshTokenHash: string,
    next: { refreshTokenHash: string; expiresAt: Date },
    at: Date,
  ): Promise<RotateResult> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.session.findUnique({ where: { refreshTokenHash } });
      if (!current) {
        return { status: 'missing' };
      }
      if (current.revokedAt) {
        return { status: current.revokeReason === 'REUSE' ? 'reuse' : 'revoked' };
      }
      if (current.expiresAt <= at) {
        return { status: 'expired' };
      }
      if (current.rotatedAt) {
        await tx.session.updateMany({
          where: { familyId: current.familyId, revokedAt: null },
          data: { revokedAt: at, revokeReason: 'REUSE' },
        });
        return { status: 'reuse' };
      }

      const claimed = await tx.session.updateMany({
        where: { id: current.id, rotatedAt: null, revokedAt: null },
        data: { rotatedAt: at },
      });
      if (claimed.count !== 1) {
        await tx.session.updateMany({
          where: { familyId: current.familyId, revokedAt: null },
          data: { revokedAt: at, revokeReason: 'REUSE' },
        });
        return { status: 'reuse' };
      }

      const created = await tx.session.create({
        data: {
          userId: current.userId,
          familyId: current.familyId,
          channel: current.channel,
          refreshTokenHash: next.refreshTokenHash,
          expiresAt: next.expiresAt,
          deviceLabel: current.deviceLabel,
          userAgent: current.userAgent,
          ipAddress: current.ipAddress,
          lastSeenAt: at,
        },
      });
      return { status: 'rotated', session: mapSession(created) };
    });
  }

  async revokeSession(id: string, reason: RevokeReasonName, at: Date): Promise<void> {
    await this.db.session.updateMany({
      where: { id, revokedAt: null },
      data: { revokedAt: at, revokeReason: reason },
    });
  }

  async revokeUserSessions(userId: string, channel: StoredChannel, at: Date): Promise<void> {
    await this.db.session.updateMany({
      where: { userId, channel, revokedAt: null },
      data: { revokedAt: at, revokeReason: 'USER' },
    });
  }

  async revokeAllUserSessions(userId: string, at: Date): Promise<void> {
    await this.db.session.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: at, revokeReason: 'USER' },
    });
  }

  async listGrants(userId: string): Promise<RoleGrantRecord[]> {
    const grants = await this.db.roleGrant.findMany({ where: { userId } });
    return grants.map((grant) => ({
      id: grant.id,
      role: grant.role,
      status: grant.status,
    }));
  }

  async listGrantsByStatus(
    status: GrantStatusName,
    page: number,
    limit: number,
  ): Promise<{ items: OpsRoleGrantListItem[]; total: number }> {
    const roles: RoleName[] = ['CUSTOMER', 'DRIVER', 'MERCHANT'];
    const where = {
      status,
      role: { in: roles },
    };
    const [rows, total] = await Promise.all([
      this.db.roleGrant.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              displayName: true,
              phone: true,
              contactPhone: true,
              email: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.db.roleGrant.count({ where }),
    ]);
    return {
      items: rows.map((row) => ({
        id: row.id,
        role: row.role,
        status: row.status,
        userId: row.userId,
        displayName: row.user.displayName,
        phone: row.user.phone?.trim() || row.user.contactPhone?.trim() || null,
        email: row.user.email,
        createdAt: row.createdAt,
      })),
      total,
    };
  }

  async listUsersByRole(
    role: RoleName,
    page: number,
    limit: number,
    filter?: {
      q?: string;
      status?: GrantStatusName;
      region?: string;
      activity?: string;
      kyc?: string;
      staffRole?: string;
      scope?: string;
      service?: string;
    },
  ): Promise<OpsUserPage> {
    const baseAnd = this.buildUserRoleFilters(role, {
      ...filter,
      status: undefined,
    });
    const listAnd = this.buildUserRoleFilters(role, filter);
    const where = { AND: listAnd };
    const facetWhere = { AND: baseAnd };

    const [total, users, statusGroups] = await Promise.all([
      this.db.user.count({ where }),
      this.db.user.findMany({
        where,
        include: { roleGrants: true, opsCredential: true },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      role === 'OPS'
        ? this.db.roleGrant.groupBy({
            by: ['status'],
            where: {
              role: 'OPS',
              user: facetWhere,
            },
            _count: { _all: true },
          })
        : Promise.resolve([] as Array<{ status: string; _count: { _all: number } }>),
    ]);

    const counts =
      role === 'OPS'
        ? {
            active: 0,
            pending: 0,
            suspended: 0,
          }
        : undefined;
    if (counts) {
      for (const row of statusGroups) {
        if (row.status === 'ACTIVE') counts.active = row._count._all;
        else if (row.status === 'PENDING') counts.pending = row._count._all;
        else if (row.status === 'SUSPENDED') counts.suspended = row._count._all;
      }
    }

    return {
      total,
      ...(counts ? { counts } : {}),
      items: users.map((user) => ({
        id: user.id,
        email: user.email,
        phone: user.phone?.trim() || user.contactPhone?.trim() || null,
        displayName: user.displayName,
        phoneVerifiedAt: user.phoneVerifiedAt,
        emailVerifiedAt: user.emailVerifiedAt,
        createdAt: user.createdAt,
        deletedAt: user.deletedAt,
        purgeAfter: user.purgeAfter,
        purgedAt: user.purgedAt,
        grants: user.roleGrants.map((grant) => ({
          id: grant.id,
          role: grant.role,
          status: grant.status,
        })),
        staffRole:
          role === 'OPS'
            ? (user.opsCredential?.staffRole ?? 'OPS')
            : user.opsCredential?.staffRole,
        superAdmin:
          role === 'OPS'
            ? user.opsCredential?.superAdmin === true
            : user.opsCredential?.superAdmin,
        scope: role === 'OPS' ? ('NATIONAL' as const) : undefined,
      })),
    };
  }

  private buildUserRoleFilters(
    role: RoleName,
    filter?: {
      q?: string;
      status?: GrantStatusName;
      region?: string;
      activity?: string;
      kyc?: string;
      staffRole?: string;
      scope?: string;
      service?: string;
    },
  ): any[] {
    const and: any[] = [
      {
        roleGrants: {
          some: filter?.status ? { role, status: filter.status } : { role },
        },
      },
    ];
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim();
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          q,
        );
      const orConditions: any[] = [
        { displayName: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { contactPhone: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
      ];
      if (isUuid) {
        orConditions.push({ id: q });
      }
      and.push({ OR: orConditions });
    }
    if (role === 'CUSTOMER' && filter?.region && filter.region !== 'ALL') {
      const reg = filter.region.toUpperCase();
      and.push({
        OR: [
          { customerRides: { some: { serviceRegionCode: reg } } },
          { customerFoodOrders: { some: { serviceRegionCode: reg } } },
        ],
      });
    }
    if (role === 'DRIVER' && filter?.region && filter.region !== 'ALL') {
      and.push({
        driverPresence: { serviceRegionCode: filter.region.toUpperCase() },
      });
    }
    if (role === 'DRIVER' && filter?.activity && filter.activity !== 'ALL') {
      const activity = filter.activity.toUpperCase();
      if (activity === 'ONLINE') {
        and.push({ driverPresence: { online: true } });
      } else if (activity === 'OFFLINE') {
        and.push({
          OR: [
            { driverPresence: { is: null } },
            { driverPresence: { online: false } },
          ],
        });
      } else if (activity === 'SUSPENDED') {
        and.push({
          roleGrants: { some: { role: 'DRIVER', status: 'SUSPENDED' } },
        });
      } else if (activity === 'BUSY') {
        and.push({
          OR: [
            {
              assignedRides: {
                some: {
                  status: {
                    in: [
                      'ASSIGNED',
                      'DRIVER_EN_ROUTE',
                      'DRIVER_ARRIVED',
                      'IN_TRIP',
                    ],
                  },
                },
              },
            },
            {
              assignedFoodOrders: {
                some: {
                  status: { in: ['ASSIGNED', 'PICKED_UP'] },
                },
              },
            },
          ],
        });
      }
    }
    if (role === 'DRIVER' && filter?.kyc && filter.kyc !== 'ALL') {
      const kyc = filter.kyc.toUpperCase();
      if (kyc === 'APPROVED') {
        and.push({
          partnerApplications: {
            some: { role: 'DRIVER', status: 'APPROVED' },
          },
        });
      } else if (kyc === 'REJECTED') {
        and.push({
          partnerApplications: {
            some: { role: 'DRIVER', status: 'REJECTED' },
          },
        });
      } else if (
        kyc === 'PENDING' ||
        kyc === 'NEED_MORE' ||
        kyc === 'NEEDS_MORE_INFO'
      ) {
        and.push({
          partnerApplications: {
            some: {
              role: 'DRIVER',
              status: { in: ['DRAFT', 'SUBMITTED'] },
            },
          },
        });
      }
    }
    if (role === 'OPS' && filter?.staffRole && filter.staffRole !== 'ALL') {
      const staffRole = filter.staffRole.toUpperCase();
      if (staffRole === 'ADMIN') {
        and.push({ opsCredential: { isNot: null } });
      } else if (
        staffRole === 'OPS' ||
        staffRole === 'SUPPORT' ||
        staffRole === 'FINANCE'
      ) {
        // SUPPORT/FINANCE alias to credential-absent OPS until dedicated RBAC grants exist.
        and.push({ opsCredential: { is: null } });
      }
    }
    // Scope is not persisted; CITY/ZONE are no-ops (return national staff).
    this.applyServiceActivityFilter(and, role, filter?.service);
    return and;
  }

  private applyServiceActivityFilter(
    and: any[],
    role: RoleName,
    service?: string,
  ): void {
    if (!service || service === 'ALL') {
      return;
    }
    const key = service.toUpperCase();
    if (role === 'CUSTOMER') {
      if (key === 'RIDE') {
        and.push({ customerRides: { some: {} } });
      } else if (key === 'FOOD' || key === 'DELIVERY') {
        and.push({ customerFoodOrders: { some: {} } });
      }
      return;
    }
    if (role === 'DRIVER') {
      if (key === 'RIDE') {
        and.push({
          OR: [{ assignedRides: { some: {} } }, { driverOffers: { some: {} } }],
        });
      } else if (key === 'FOOD' || key === 'DELIVERY') {
        and.push({ assignedFoodOrders: { some: {} } });
      }
    }
  }

  async findUserDirectory(id: string): Promise<OpsUserDirectoryRecord | null> {
    const user = await this.db.user.findUnique({
      where: { id },
      include: { roleGrants: true, opsCredential: true },
    });
    if (!user) {
      return null;
    }
    return {
      id: user.id,
      email: user.email,
      phone: user.phone?.trim() || user.contactPhone?.trim() || null,
      displayName: user.displayName,
      phoneVerifiedAt: user.phoneVerifiedAt,
      emailVerifiedAt: user.emailVerifiedAt,
      createdAt: user.createdAt,
      deletedAt: user.deletedAt,
      purgeAfter: user.purgeAfter,
      purgedAt: user.purgedAt,
      grants: user.roleGrants.map((grant) => ({
        id: grant.id,
        role: grant.role,
        status: grant.status,
      })),
      ...(user.opsCredential?.staffRole
        ? { staffRole: user.opsCredential.staffRole }
        : {}),
      ...(user.opsCredential?.superAdmin !== undefined
        ? { superAdmin: user.opsCredential.superAdmin }
        : {}),
      ...(user.opsCredential ? { scope: 'NATIONAL' as const } : {}),
    };
  }

  async insertGrant(
    userId: string,
    role: RoleName,
    status: GrantStatusName,
  ): Promise<RoleGrantRecord> {
    try {
      const grant = await this.db.roleGrant.create({ data: { userId, role, status } });
      return { id: grant.id, role: grant.role, status: grant.status };
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async findGrantById(id: string): Promise<(RoleGrantRecord & { userId: string }) | null> {
    const grant = await this.db.roleGrant.findUnique({ where: { id } });
    if (!grant) {
      return null;
    }
    return {
      id: grant.id,
      userId: grant.userId,
      role: grant.role,
      status: grant.status,
    };
  }

  async updateGrantStatus(id: string, status: GrantStatusName): Promise<RoleGrantRecord | null> {
    try {
      const grant = await this.db.roleGrant.update({
        where: { id },
        data: { status },
      });
      return { id: grant.id, role: grant.role, status: grant.status };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        return null;
      }
      throw error;
    }
  }

  async findOpsCredential(userId: string): Promise<OpsCredentialRecord | null> {
    const credential = await this.db.opsCredential.findUnique({ where: { userId } });
    if (!credential?.passwordHash) {
      return null;
    }
    return {
      passwordHash: credential.passwordHash,
      superAdmin: credential.superAdmin,
      staffRole: credential.staffRole,
    };
  }

  async setOpsStaffRole(input: {
    targetUserId: string;
    staffRole: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE';
    actorUserId: string;
    reason: string;
  }): Promise<'ok' | 'unchanged' | 'no_credential'> {
    return this.db.$transaction(async (tx) => {
      const target = await tx.opsCredential.findUnique({ where: { userId: input.targetUserId } });
      if (!target?.passwordHash) return 'no_credential' as const;
      if (target.staffRole === input.staffRole) return 'unchanged' as const;
      await tx.opsCredential.update({
        where: { userId: input.targetUserId },
        data: { staffRole: input.staffRole },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'OPS_STAFF_ROLE_ASSIGN',
          entityType: 'OPS_STAFF',
          entityId: input.targetUserId,
          reason: input.reason,
          metadata: { staffRole: input.staffRole, previous: target.staffRole },
        },
      });
      return 'ok' as const;
    });
  }

  async setOpsSuperAdmin(userId: string, superAdmin: boolean): Promise<void> {
    await this.db.opsCredential.updateMany({ where: { userId }, data: { superAdmin } });
  }

  async resetOpsPassword(input: OpsPasswordResetInput): Promise<void> {
    await this.db.$transaction(async (tx) => {
      const updated = await tx.opsCredential.updateMany({
        where: { userId: input.targetUserId, passwordHash: { not: null } },
        data: { passwordHash: input.passwordHash },
      });
      if (updated.count !== 1) {
        throw new Error('OPS_NO_PASSWORD_LOGIN');
      }
      await tx.session.updateMany({
        where: { userId: input.targetUserId, channel: 'OPS', revokedAt: null },
        data: { revokedAt: input.at, revokeReason: 'USER' },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'OPS_PASSWORD_RESET',
          entityType: 'OPS_STAFF',
          entityId: input.targetUserId,
          reason: input.reason,
          // Never the password or its hash.
          metadata: { sessionsRevoked: true },
        },
      });
    });
  }

  async changeOpsSuperAdmin(input: OpsSuperAdminChangeInput): Promise<OpsSuperAdminChangeResult> {
    return this.db.$transaction(async (tx) => {
      // Serializes concurrent grant/revoke so two admins cannot revoke each other to zero.
      await tx.$queryRaw`SELECT "userId" FROM "ops_credentials" WHERE "superAdmin" = true OR "userId" = ${input.targetUserId}::uuid FOR UPDATE`;
      const target = await tx.opsCredential.findUnique({ where: { userId: input.targetUserId } });
      if (!target?.passwordHash) {
        return 'no_credential' as const;
      }
      if (target.superAdmin === input.superAdmin) {
        return 'unchanged' as const;
      }
      if (!input.superAdmin) {
        const others = await tx.opsCredential.count({
          where: {
            superAdmin: true,
            userId: { not: input.targetUserId },
            user: { roleGrants: { some: { role: 'OPS', status: 'ACTIVE' } } },
          },
        });
        if (others === 0) {
          return 'last' as const;
        }
      }
      await tx.opsCredential.update({
        where: { userId: input.targetUserId },
        data: { superAdmin: input.superAdmin },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: input.superAdmin ? 'OPS_SUPER_ADMIN_GRANT' : 'OPS_SUPER_ADMIN_REVOKE',
          entityType: 'OPS_STAFF',
          entityId: input.targetUserId,
          reason: input.reason,
          metadata: { superAdmin: input.superAdmin },
        },
      });
      return 'ok' as const;
    });
  }

  async saveOpsCredential(userId: string, passwordHash: string): Promise<void> {
    await this.db.opsCredential.upsert({
      where: { userId },
      create: { userId, passwordHash, staffRole: 'ADMIN' },
      update: { passwordHash },
    });
  }

  async findCustomerCredential(userId: string): Promise<{ passwordHash: string } | null> {
    const credential = await this.db.customerCredential.findUnique({ where: { userId } });
    if (!credential?.passwordHash) {
      return null;
    }
    return { passwordHash: credential.passwordHash };
  }

  async saveCustomerCredential(userId: string, passwordHash: string): Promise<void> {
    await this.db.customerCredential.upsert({
      where: { userId },
      create: { userId, passwordHash },
      update: { passwordHash },
    });
  }

  async listPasskeys(userId: string): Promise<PasskeyRecord[]> {
    const passkeys = await this.db.passkey.findMany({ where: { userId } });
    return passkeys.map(mapPasskey);
  }

  async findPasskeyByCredentialId(credentialId: string): Promise<PasskeyRecord | null> {
    const passkey = await this.db.passkey.findUnique({ where: { credentialId } });
    return passkey ? mapPasskey(passkey) : null;
  }

  async savePasskey(input: {
    userId: string;
    credentialId: string;
    publicKey: Uint8Array;
    counter: number;
    transports: string[];
    deviceType: string | null;
    backedUp: boolean;
  }): Promise<PasskeyRecord> {
    try {
      const passkey = await this.db.passkey.create({
        data: {
          userId: input.userId,
          credentialId: input.credentialId,
          publicKey: Buffer.from(input.publicKey),
          counter: input.counter,
          transports: input.transports,
          deviceType: input.deviceType,
          backedUp: input.backedUp,
        },
      });
      return mapPasskey(passkey);
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async updatePasskeyCounter(id: string, counter: number): Promise<void> {
    await this.db.passkey.update({ where: { id }, data: { counter } });
  }

  async createPasskeyUser(
    input: Omit<Parameters<IdentityRepository['savePasskey']>[0], 'userId'>,
  ): Promise<UserRecord> {
    try {
      const user = await this.db.$transaction(async (tx) => {
        const created = await tx.user.create({ data: { displayName: 'DealGo user' } });
        await tx.roleGrant.create({
          data: { userId: created.id, role: 'CUSTOMER', status: 'ACTIVE' },
        });
        await tx.passkey.create({
          data: {
            ...input,
            userId: created.id,
            publicKey: Buffer.from(input.publicKey),
          },
        });
        return created;
      });
      return mapUser(user);
    } catch (error) {
      throw mapUnique(error);
    }
  }

  async replacePasskeyChallenge(input: {
    userId: string | null;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord> {
    return this.db.$transaction(async (tx) => {
      if (input.userId !== null) {
        await tx.passkeyChallenge.updateMany({
          where: { userId: input.userId, kind: input.kind, consumedAt: null },
          data: { consumedAt: new Date() },
        });
      }
      const created = await tx.passkeyChallenge.create({ data: input });
      return mapCeremony(created);
    });
  }

  async findOpenPasskeyChallenge(
    userId: string,
    kind: PasskeyCeremonyName,
  ): Promise<PasskeyChallengeRecord | null> {
    const challenge = await this.db.passkeyChallenge.findFirst({
      where: { userId, kind, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    return challenge ? mapCeremony(challenge) : null;
  }

  async findPasskeyChallenge(id: string): Promise<PasskeyChallengeRecord | null> {
    const challenge = await this.db.passkeyChallenge.findUnique({ where: { id } });
    return challenge ? mapCeremony(challenge) : null;
  }

  async consumePasskeyChallenge(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.passkeyChallenge.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }
}

function mapUser(user: DbUser): UserRecord {
  return {
    id: user.id,
    email: user.email,
    phone: user.phone,
    displayName: user.displayName,
    dateOfBirth: user.dateOfBirth,
    gender: user.gender,
    avatarUrl: user.avatarUrl,
    phoneVerifiedAt: user.phoneVerifiedAt,
    emailVerifiedAt: user.emailVerifiedAt,
    contactPhone: user.contactPhone ?? null,
    createdAt: user.createdAt,
    deletedAt: user.deletedAt,
    purgeAfter: user.purgeAfter,
    purgedAt: user.purgedAt,
  };
}

function mapEmail(verification: {
  id: string;
  userId: string;
  email: string;
  tokenHash: string;
  expiresAt: Date;
  attemptCount: number;
  lastSentAt: Date;
  consumedAt: Date | null;
  createdAt: Date;
}): EmailVerificationRecord {
  return {
    id: verification.id,
    userId: verification.userId,
    email: verification.email,
    tokenHash: verification.tokenHash,
    expiresAt: verification.expiresAt,
    attemptCount: verification.attemptCount,
    lastSentAt: verification.lastSentAt,
    consumedAt: verification.consumedAt,
    createdAt: verification.createdAt,
  };
}

function mapPasswordReset(reset: {
  id: string;
  userId: string | null;
  email: string;
  tokenHash: string;
  expiresAt: Date;
  attemptCount: number;
  sendCount: number;
  lastSentAt: Date;
  consumedAt: Date | null;
  createdAt: Date;
}): PasswordResetRecord {
  return {
    id: reset.id,
    userId: reset.userId,
    email: reset.email,
    tokenHash: reset.tokenHash,
    expiresAt: reset.expiresAt,
    attemptCount: reset.attemptCount,
    sendCount: reset.sendCount,
    lastSentAt: reset.lastSentAt,
    consumedAt: reset.consumedAt,
    createdAt: reset.createdAt,
  };
}

function mapSession(session: {
  id: string;
  userId: string;
  familyId: string;
  channel: StoredChannel;
  refreshTokenHash: string;
  expiresAt: Date;
  rotatedAt: Date | null;
  revokedAt: Date | null;
  revokeReason: RevokeReasonName | null;
  deviceId?: string | null;
  deviceLabel: string | null;
  userAgent: string | null;
  ipAddress: string | null;
  lastSeenAt: Date;
  createdAt: Date;
}): SessionRecord {
  return {
    id: session.id,
    userId: session.userId,
    familyId: session.familyId,
    channel: session.channel,
    refreshTokenHash: session.refreshTokenHash,
    expiresAt: session.expiresAt,
    rotatedAt: session.rotatedAt,
    revokedAt: session.revokedAt,
    revokeReason: session.revokeReason,
    deviceId: session.deviceId ?? null,
    deviceLabel: session.deviceLabel,
    userAgent: session.userAgent,
    ipAddress: session.ipAddress,
    lastSeenAt: session.lastSeenAt,
    createdAt: session.createdAt,
  };
}

function mapPasskey(passkey: {
  id: string;
  userId: string;
  credentialId: string;
  publicKey: Uint8Array;
  counter: number;
  transports: string[];
  deviceType: string | null;
  backedUp: boolean;
}): PasskeyRecord {
  return {
    id: passkey.id,
    userId: passkey.userId,
    credentialId: passkey.credentialId,
    publicKey: new Uint8Array(passkey.publicKey),
    counter: passkey.counter,
    transports: passkey.transports,
    deviceType: passkey.deviceType,
    backedUp: passkey.backedUp,
  };
}

function mapCeremony(challenge: {
  id: string;
  userId: string | null;
  kind: PasskeyCeremonyName;
  challenge: string;
  expiresAt: Date;
  consumedAt: Date | null;
}): PasskeyChallengeRecord {
  return challenge;
}

function mapUnique(error: unknown): unknown {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
    return new UniqueConflictError();
  }
  return error;
}
