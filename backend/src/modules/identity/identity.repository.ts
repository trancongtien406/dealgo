import { randomUUID } from 'node:crypto';
import type { SessionChannelName } from '../../platform/security/token-crypto.js';

export type RoleName = 'CUSTOMER' | 'MERCHANT' | 'DRIVER' | 'OPS';
export type GrantStatusName = 'PENDING' | 'ACTIVE' | 'SUSPENDED';
export type RevokeReasonName = 'USER' | 'REUSE';
export type PasskeyCeremonyName = 'REGISTRATION' | 'AUTHENTICATION';
export type StoredChannel = 'CUSTOMER' | 'OPS';

export class UniqueConflictError extends Error {
  constructor() {
    super('Unique constraint failed');
    this.name = 'UniqueConflictError';
  }
}

export type UserRecord = {
  id: string;
  email: string | null;
  phone: string | null;
  displayName: string;
  phoneVerifiedAt: Date | null;
  emailVerifiedAt: Date | null;
  createdAt: Date;
};

export type RoleGrantRecord = {
  id: string;
  role: RoleName;
  status: GrantStatusName;
};

export type OpsRoleGrantListItem = RoleGrantRecord & {
  userId: string;
  displayName: string;
  phone: string | null;
  email: string | null;
  createdAt: Date;
};

/** Safe ops directory projection — never includes credentials or session tokens. */
export type OpsUserDirectoryRecord = {
  id: string;
  email: string | null;
  phone: string | null;
  displayName: string;
  phoneVerifiedAt: Date | null;
  emailVerifiedAt: Date | null;
  createdAt: Date;
  grants: RoleGrantRecord[];
  /** Derived for OPS staff rows: ADMIN if OpsCredential exists, else OPS. */
  staffRole?: 'ADMIN' | 'OPS';
  /** Scope is not persisted yet; pilot staff are NATIONAL. */
  scope?: 'NATIONAL' | 'CITY' | 'ZONE';
};

export type OpsStaffStatusCounts = {
  active: number;
  pending: number;
  suspended: number;
};

export type OpsUserPage = {
  items: OpsUserDirectoryRecord[];
  total: number;
  /** Status facet for the filtered staff set (ignores status filter). */
  counts?: OpsStaffStatusCounts;
};

export type PhoneChallengeRecord = {
  id: string;
  userId: string;
  phone: string;
  codeHash: string;
  expiresAt: Date;
  attemptCount: number;
  consumedAt: Date | null;
};

export type EmailVerificationRecord = {
  id: string;
  userId: string;
  email: string;
  tokenHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
};

export type SessionRecord = {
  id: string;
  userId: string;
  familyId: string;
  channel: StoredChannel;
  refreshTokenHash: string;
  expiresAt: Date;
  rotatedAt: Date | null;
  revokedAt: Date | null;
  revokeReason: RevokeReasonName | null;
};

export type RotateResult =
  | { status: 'rotated'; session: SessionRecord }
  | { status: 'reuse' }
  | { status: 'revoked' }
  | { status: 'expired' }
  | { status: 'missing' };

export type PasskeyRecord = {
  id: string;
  userId: string;
  credentialId: string;
  publicKey: Uint8Array;
  counter: number;
  transports: string[];
  deviceType: string | null;
  backedUp: boolean;
};

export type PasskeyChallengeRecord = {
  id: string;
  userId: string;
  kind: PasskeyCeremonyName;
  challenge: string;
  expiresAt: Date;
  consumedAt: Date | null;
};

export type NewSession = {
  userId: string;
  familyId: string;
  channel: StoredChannel;
  refreshTokenHash: string;
  expiresAt: Date;
};

export function storedChannel(channel: SessionChannelName): StoredChannel {
  return channel === 'ops' ? 'OPS' : 'CUSTOMER';
}

export function sessionChannel(channel: StoredChannel): SessionChannelName {
  return channel === 'OPS' ? 'ops' : 'customer';
}

export interface IdentityRepository {
  findUserById(id: string): Promise<UserRecord | null>;
  findUserByPhone(phone: string): Promise<UserRecord | null>;
  findUserByEmail(email: string): Promise<UserRecord | null>;
  createUser(input: {
    email: string | null;
    phone: string | null;
    displayName: string;
  }): Promise<UserRecord>;
  markPhoneVerified(userId: string, at: Date): Promise<UserRecord>;
  setEmailVerified(userId: string, email: string, at: Date): Promise<UserRecord>;

  createPhoneChallenge(input: {
    userId: string;
    phone: string;
    codeHash: string;
    expiresAt: Date;
  }): Promise<PhoneChallengeRecord>;
  findPhoneChallenge(id: string): Promise<PhoneChallengeRecord | null>;
  recordFailedPhoneAttempt(id: string): Promise<PhoneChallengeRecord>;
  consumePhoneChallenge(id: string, at: Date): Promise<boolean>;

  createEmailVerification(input: {
    userId: string;
    email: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<EmailVerificationRecord>;
  findEmailVerification(id: string): Promise<EmailVerificationRecord | null>;
  consumeEmailVerification(id: string, at: Date): Promise<boolean>;

  createSession(input: NewSession): Promise<SessionRecord>;
  findSessionById(id: string): Promise<SessionRecord | null>;
  findSessionByRefreshTokenHash(refreshTokenHash: string): Promise<SessionRecord | null>;
  rotateSession(
    refreshTokenHash: string,
    next: { refreshTokenHash: string; expiresAt: Date },
    at: Date,
  ): Promise<RotateResult>;
  revokeSession(id: string, reason: RevokeReasonName, at: Date): Promise<void>;

  listGrants(userId: string): Promise<RoleGrantRecord[]>;
  listGrantsByStatus(
    status: GrantStatusName,
    page: number,
    limit: number,
  ): Promise<{ items: OpsRoleGrantListItem[]; total: number }>;
  listUsersByRole(
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
  ): Promise<OpsUserPage>;
  findUserDirectory(id: string): Promise<OpsUserDirectoryRecord | null>;
  insertGrant(
    userId: string,
    role: RoleName,
    status: GrantStatusName,
  ): Promise<RoleGrantRecord>;
  findGrantById(id: string): Promise<(RoleGrantRecord & { userId: string }) | null>;
  updateGrantStatus(id: string, status: GrantStatusName): Promise<RoleGrantRecord | null>;
  findOpsCredential(userId: string): Promise<{ passwordHash: string } | null>;
  saveOpsCredential(userId: string, passwordHash: string): Promise<void>;

  listPasskeys(userId: string): Promise<PasskeyRecord[]>;
  findPasskeyByCredentialId(credentialId: string): Promise<PasskeyRecord | null>;
  savePasskey(input: {
    userId: string;
    credentialId: string;
    publicKey: Uint8Array;
    counter: number;
    transports: string[];
    deviceType: string | null;
    backedUp: boolean;
  }): Promise<PasskeyRecord>;
  updatePasskeyCounter(id: string, counter: number): Promise<void>;
  replacePasskeyChallenge(input: {
    userId: string;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord>;
  findOpenPasskeyChallenge(
    userId: string,
    kind: PasskeyCeremonyName,
  ): Promise<PasskeyChallengeRecord | null>;
  consumePasskeyChallenge(id: string, at: Date): Promise<boolean>;
}

export class MemoryIdentityRepository implements IdentityRepository {
  private readonly users = new Map<string, UserRecord>();
  private readonly grants = new Map<string, RoleGrantRecord[]>();
  private readonly phoneChallenges = new Map<string, PhoneChallengeRecord>();
  private readonly emailVerifications = new Map<string, EmailVerificationRecord>();
  private readonly sessions = new Map<string, SessionRecord>();
  private readonly credentials = new Map<string, { passwordHash: string }>();
  private readonly passkeys = new Map<string, PasskeyRecord>();
  private readonly passkeyChallenges = new Map<string, PasskeyChallengeRecord>();

  async findUserById(id: string): Promise<UserRecord | null> {
    return this.users.get(id) ?? null;
  }

  async findUserByPhone(phone: string): Promise<UserRecord | null> {
    return [...this.users.values()].find((user) => user.phone === phone) ?? null;
  }

  async findUserByEmail(email: string): Promise<UserRecord | null> {
    return [...this.users.values()].find((user) => user.email === email) ?? null;
  }

  async createUser(input: {
    email: string | null;
    phone: string | null;
    displayName: string;
  }): Promise<UserRecord> {
    if (input.phone && (await this.findUserByPhone(input.phone))) {
      throw new UniqueConflictError();
    }
    if (input.email && (await this.findUserByEmail(input.email))) {
      throw new UniqueConflictError();
    }
    const user: UserRecord = {
      id: randomUUID(),
      email: input.email,
      phone: input.phone,
      displayName: input.displayName,
      phoneVerifiedAt: null,
      emailVerifiedAt: null,
      createdAt: new Date(),
    };
    this.users.set(user.id, user);
    return user;
  }

  async markPhoneVerified(userId: string, at: Date): Promise<UserRecord> {
    const user = this.requireUser(userId);
    user.phoneVerifiedAt = at;
    return user;
  }

  async setEmailVerified(userId: string, email: string, at: Date): Promise<UserRecord> {
    const taken = await this.findUserByEmail(email);
    if (taken && taken.id !== userId) {
      throw new UniqueConflictError();
    }
    const user = this.requireUser(userId);
    user.email = email;
    user.emailVerifiedAt = at;
    return user;
  }

  async createPhoneChallenge(input: {
    userId: string;
    phone: string;
    codeHash: string;
    expiresAt: Date;
  }): Promise<PhoneChallengeRecord> {
    const challenge: PhoneChallengeRecord = {
      id: randomUUID(),
      userId: input.userId,
      phone: input.phone,
      codeHash: input.codeHash,
      expiresAt: input.expiresAt,
      attemptCount: 0,
      consumedAt: null,
    };
    this.phoneChallenges.set(challenge.id, challenge);
    return challenge;
  }

  async findPhoneChallenge(id: string): Promise<PhoneChallengeRecord | null> {
    return this.phoneChallenges.get(id) ?? null;
  }

  async recordFailedPhoneAttempt(id: string): Promise<PhoneChallengeRecord> {
    const challenge = this.phoneChallenges.get(id);
    if (!challenge) {
      throw new Error('Phone challenge not found');
    }
    challenge.attemptCount += 1;
    return challenge;
  }

  async consumePhoneChallenge(id: string, at: Date): Promise<boolean> {
    const challenge = this.phoneChallenges.get(id);
    if (!challenge || challenge.consumedAt) {
      return false;
    }
    challenge.consumedAt = at;
    return true;
  }

  async createEmailVerification(input: {
    userId: string;
    email: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<EmailVerificationRecord> {
    const verification: EmailVerificationRecord = {
      id: randomUUID(),
      userId: input.userId,
      email: input.email,
      tokenHash: input.tokenHash,
      expiresAt: input.expiresAt,
      consumedAt: null,
    };
    this.emailVerifications.set(verification.id, verification);
    return verification;
  }

  async findEmailVerification(id: string): Promise<EmailVerificationRecord | null> {
    return this.emailVerifications.get(id) ?? null;
  }

  async consumeEmailVerification(id: string, at: Date): Promise<boolean> {
    const verification = this.emailVerifications.get(id);
    if (!verification || verification.consumedAt) {
      return false;
    }
    verification.consumedAt = at;
    return true;
  }

  async createSession(input: NewSession): Promise<SessionRecord> {
    const session: SessionRecord = {
      id: randomUUID(),
      userId: input.userId,
      familyId: input.familyId,
      channel: input.channel,
      refreshTokenHash: input.refreshTokenHash,
      expiresAt: input.expiresAt,
      rotatedAt: null,
      revokedAt: null,
      revokeReason: null,
    };
    this.sessions.set(session.id, session);
    return session;
  }

  async findSessionById(id: string): Promise<SessionRecord | null> {
    return this.sessions.get(id) ?? null;
  }

  async findSessionByRefreshTokenHash(refreshTokenHash: string): Promise<SessionRecord | null> {
    return (
      [...this.sessions.values()].find(
        (session) => session.refreshTokenHash === refreshTokenHash,
      ) ?? null
    );
  }

  async rotateSession(
    refreshTokenHash: string,
    next: { refreshTokenHash: string; expiresAt: Date },
    at: Date,
  ): Promise<RotateResult> {
    const current = [...this.sessions.values()].find(
      (session) => session.refreshTokenHash === refreshTokenHash,
    );
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
      this.revokeFamily(current.familyId, at);
      return { status: 'reuse' };
    }

    current.rotatedAt = at;
    const created = await this.createSession({
      userId: current.userId,
      familyId: current.familyId,
      channel: current.channel,
      refreshTokenHash: next.refreshTokenHash,
      expiresAt: next.expiresAt,
    });
    return { status: 'rotated', session: created };
  }

  async revokeSession(id: string, reason: RevokeReasonName, at: Date): Promise<void> {
    const session = this.sessions.get(id);
    if (!session || session.revokedAt) {
      return;
    }
    session.revokedAt = at;
    session.revokeReason = reason;
  }

  async listGrants(userId: string): Promise<RoleGrantRecord[]> {
    return [...(this.grants.get(userId) ?? [])];
  }

  async listGrantsByStatus(
    status: GrantStatusName,
    page: number,
    limit: number,
  ): Promise<{ items: OpsRoleGrantListItem[]; total: number }> {
    const rows: OpsRoleGrantListItem[] = [];
    for (const [userId, grants] of this.grants.entries()) {
      const user = this.users.get(userId);
      if (!user) continue;
      for (const grant of grants) {
        if (grant.status !== status) continue;
        if (grant.role === 'OPS') continue;
        rows.push({
          id: grant.id,
          role: grant.role,
          status: grant.status,
          userId,
          displayName: user.displayName,
          phone: user.phone,
          email: user.email,
          createdAt: user.createdAt,
        });
      }
    }
    rows.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const total = rows.length;
    const start = (page - 1) * limit;
    return { items: rows.slice(start, start + limit), total };
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
    const matched: OpsUserDirectoryRecord[] = [];
    const counts = { active: 0, pending: 0, suspended: 0 };
    for (const user of this.users.values()) {
      const grants = this.grants.get(user.id) ?? [];
      const roleGrant = grants.find((grant) => grant.role === role);
      if (!roleGrant) {
        continue;
      }
      if (filter?.q && filter.q.trim()) {
        const q = filter.q.trim().toLowerCase();
        const matches =
          user.displayName.toLowerCase().includes(q) ||
          (user.phone?.toLowerCase().includes(q) ?? false) ||
          (user.email?.toLowerCase().includes(q) ?? false) ||
          user.id.toLowerCase().includes(q);
        if (!matches) {
          continue;
        }
      }
      // Scope is not persisted; CITY/ZONE are no-ops (return national staff).
      const hasOpsCred = this.credentials.has(user.id);
      if (role === 'OPS' && filter?.staffRole && filter.staffRole !== 'ALL') {
        const staffRole = filter.staffRole.toUpperCase();
        if (staffRole === 'ADMIN' && !hasOpsCred) continue;
        // SUPPORT/FINANCE alias to credential-absent OPS until dedicated RBAC grants exist.
        if (
          (staffRole === 'OPS' ||
            staffRole === 'SUPPORT' ||
            staffRole === 'FINANCE') &&
          hasOpsCred
        ) {
          continue;
        }
      }
      // Memory repo has no ride/food activity; service filter is a no-op here.
      if (role === 'OPS') {
        if (roleGrant.status === 'ACTIVE') counts.active += 1;
        else if (roleGrant.status === 'PENDING') counts.pending += 1;
        else if (roleGrant.status === 'SUSPENDED') counts.suspended += 1;
      }
      if (filter?.status && roleGrant.status !== filter.status) {
        continue;
      }
      matched.push({
        id: user.id,
        email: user.email,
        phone: user.phone,
        displayName: user.displayName,
        phoneVerifiedAt: user.phoneVerifiedAt,
        emailVerifiedAt: user.emailVerifiedAt,
        createdAt: user.createdAt,
        grants: grants.map((grant) => ({ ...grant })),
        staffRole: role === 'OPS' ? (hasOpsCred ? 'ADMIN' : 'OPS') : undefined,
        scope: role === 'OPS' ? 'NATIONAL' : undefined,
      });
    }
    matched.sort(
      (left, right) =>
        right.createdAt.getTime() - left.createdAt.getTime() || left.id.localeCompare(right.id),
    );
    const total = matched.length;
    const start = (page - 1) * limit;
    return {
      items: matched.slice(start, start + limit),
      total,
      ...(role === 'OPS' ? { counts } : {}),
    };
  }

  async findUserDirectory(id: string): Promise<OpsUserDirectoryRecord | null> {
    const user = this.users.get(id);
    if (!user) {
      return null;
    }
    const grants = this.grants.get(id) ?? [];
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      displayName: user.displayName,
      phoneVerifiedAt: user.phoneVerifiedAt,
      emailVerifiedAt: user.emailVerifiedAt,
      createdAt: user.createdAt,
      grants: grants.map((grant) => ({ ...grant })),
    };
  }

  async insertGrant(
    userId: string,
    role: RoleName,
    status: GrantStatusName,
  ): Promise<RoleGrantRecord> {
    const current = this.grants.get(userId) ?? [];
    if (current.some((grant) => grant.role === role)) {
      throw new UniqueConflictError();
    }
    const grant: RoleGrantRecord = { id: randomUUID(), role, status };
    current.push(grant);
    this.grants.set(userId, current);
    return grant;
  }

  async findGrantById(id: string): Promise<(RoleGrantRecord & { userId: string }) | null> {
    for (const [userId, grants] of this.grants.entries()) {
      const grant = grants.find((entry) => entry.id === id);
      if (grant) {
        return { ...grant, userId };
      }
    }
    return null;
  }

  async updateGrantStatus(id: string, status: GrantStatusName): Promise<RoleGrantRecord | null> {
    for (const grants of this.grants.values()) {
      const grant = grants.find((entry) => entry.id === id);
      if (grant) {
        grant.status = status;
        return { ...grant };
      }
    }
    return null;
  }

  async findOpsCredential(userId: string): Promise<{ passwordHash: string } | null> {
    return this.credentials.get(userId) ?? null;
  }

  async saveOpsCredential(userId: string, passwordHash: string): Promise<void> {
    this.credentials.set(userId, { passwordHash });
  }

  async listPasskeys(userId: string): Promise<PasskeyRecord[]> {
    return [...this.passkeys.values()].filter((passkey) => passkey.userId === userId);
  }

  async findPasskeyByCredentialId(credentialId: string): Promise<PasskeyRecord | null> {
    return (
      [...this.passkeys.values()].find((passkey) => passkey.credentialId === credentialId) ?? null
    );
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
    if (await this.findPasskeyByCredentialId(input.credentialId)) {
      throw new UniqueConflictError();
    }
    const passkey: PasskeyRecord = {
      id: randomUUID(),
      userId: input.userId,
      credentialId: input.credentialId,
      publicKey: new Uint8Array(input.publicKey),
      counter: input.counter,
      transports: [...input.transports],
      deviceType: input.deviceType,
      backedUp: input.backedUp,
    };
    this.passkeys.set(passkey.id, passkey);
    return passkey;
  }

  async updatePasskeyCounter(id: string, counter: number): Promise<void> {
    const passkey = this.passkeys.get(id);
    if (!passkey) {
      throw new Error('Passkey not found');
    }
    passkey.counter = counter;
  }

  async replacePasskeyChallenge(input: {
    userId: string;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord> {
    const at = new Date();
    for (const existing of this.passkeyChallenges.values()) {
      if (existing.userId === input.userId && existing.kind === input.kind && !existing.consumedAt) {
        existing.consumedAt = at;
      }
    }
    const created: PasskeyChallengeRecord = {
      id: randomUUID(),
      userId: input.userId,
      kind: input.kind,
      challenge: input.challenge,
      expiresAt: input.expiresAt,
      consumedAt: null,
    };
    this.passkeyChallenges.set(created.id, created);
    return created;
  }

  async findOpenPasskeyChallenge(
    userId: string,
    kind: PasskeyCeremonyName,
  ): Promise<PasskeyChallengeRecord | null> {
    const open = [...this.passkeyChallenges.values()]
      .filter((challenge) => challenge.userId === userId && challenge.kind === kind && !challenge.consumedAt)
      .sort((left, right) => right.expiresAt.getTime() - left.expiresAt.getTime());
    return open[0] ?? null;
  }

  async consumePasskeyChallenge(id: string, at: Date): Promise<boolean> {
    const challenge = this.passkeyChallenges.get(id);
    if (!challenge || challenge.consumedAt) {
      return false;
    }
    challenge.consumedAt = at;
    return true;
  }

  private requireUser(userId: string): UserRecord {
    const user = this.users.get(userId);
    if (!user) {
      throw new Error('User not found');
    }
    return user;
  }

  private revokeFamily(familyId: string, at: Date): void {
    for (const session of this.sessions.values()) {
      if (session.familyId === familyId && !session.revokedAt) {
        session.revokedAt = at;
        session.revokeReason = 'REUSE';
      }
    }
  }
}
