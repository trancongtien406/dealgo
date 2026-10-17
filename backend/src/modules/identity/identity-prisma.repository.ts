import { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import {
  UniqueConflictError,
  type EmailVerificationRecord,
  type GrantStatusName,
  type IdentityRepository,
  type NewSession,
  type OpsRoleGrantListItem,
  type OpsUserDirectoryRecord,
  type OpsUserPage,
  type PasskeyCeremonyName,
  type PasskeyChallengeRecord,
  type PasskeyRecord,
  type PhoneChallengeRecord,
  type RevokeReasonName,
  type RoleGrantRecord,
  type RoleName,
  type RotateResult,
  type SessionRecord,
  type StoredChannel,
  type UserRecord,
} from './identity.repository.js';

type DbUser = {
  id: string;
  email: string | null;
  phone: string | null;
  displayName: string;
  phoneVerifiedAt: Date | null;
  emailVerifiedAt: Date | null;
  createdAt: Date;
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
  }): Promise<UserRecord> {
    try {
      const user = await this.db.user.create({
        data: {
          email: input.email,
          phone: input.phone,
          displayName: input.displayName,
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

  async createPhoneChallenge(input: {
    userId: string;
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
  }): Promise<EmailVerificationRecord> {
    const verification = await this.db.emailVerification.create({ data: input });
    return mapEmail(verification);
  }

  async findEmailVerification(id: string): Promise<EmailVerificationRecord | null> {
    const verification = await this.db.emailVerification.findUnique({ where: { id } });
    return verification ? mapEmail(verification) : null;
  }

  async consumeEmailVerification(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.emailVerification.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: at },
    });
    return updated.count === 1;
  }

  async createSession(input: NewSession): Promise<SessionRecord> {
    const session = await this.db.session.create({ data: input });
    return mapSession(session);
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
        phone: row.user.phone,
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
        phone: user.phone,
        displayName: user.displayName,
        phoneVerifiedAt: user.phoneVerifiedAt,
        emailVerifiedAt: user.emailVerifiedAt,
        createdAt: user.createdAt,
        grants: user.roleGrants.map((grant) => ({
          id: grant.id,
          role: grant.role,
          status: grant.status,
        })),
        staffRole: user.opsCredential ? 'ADMIN' : 'OPS',
        scope: 'NATIONAL' as const,
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
        { email: { contains: q, mode: 'insensitive' } },
      ];
      if (isUuid) {
        orConditions.push({ id: q });
      }
      and.push({ OR: orConditions });
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
      include: { roleGrants: true },
    });
    if (!user) {
      return null;
    }
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      displayName: user.displayName,
      phoneVerifiedAt: user.phoneVerifiedAt,
      emailVerifiedAt: user.emailVerifiedAt,
      createdAt: user.createdAt,
      grants: user.roleGrants.map((grant) => ({
        id: grant.id,
        role: grant.role,
        status: grant.status,
      })),
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

  async findOpsCredential(userId: string): Promise<{ passwordHash: string } | null> {
    const credential = await this.db.opsCredential.findUnique({ where: { userId } });
    if (!credential?.passwordHash) {
      return null;
    }
    return { passwordHash: credential.passwordHash };
  }

  async saveOpsCredential(userId: string, passwordHash: string): Promise<void> {
    await this.db.opsCredential.upsert({
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

  async replacePasskeyChallenge(input: {
    userId: string;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord> {
    return this.db.$transaction(async (tx) => {
      await tx.passkeyChallenge.updateMany({
        where: { userId: input.userId, kind: input.kind, consumedAt: null },
        data: { consumedAt: new Date() },
      });
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
    phoneVerifiedAt: user.phoneVerifiedAt,
    emailVerifiedAt: user.emailVerifiedAt,
    createdAt: user.createdAt,
  };
}

function mapEmail(verification: {
  id: string;
  userId: string;
  email: string;
  tokenHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
}): EmailVerificationRecord {
  return verification;
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
}): SessionRecord {
  return session;
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
  userId: string;
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
