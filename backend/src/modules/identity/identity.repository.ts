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

export type UserGenderName = 'MALE' | 'FEMALE' | 'OTHER';

export type UserRecord = {
  id: string;
  email: string | null;
  phone: string | null;
  displayName: string;
  dateOfBirth: Date | null;
  gender: UserGenderName | null;
  avatarUrl: string | null;
  phoneVerifiedAt: Date | null;
  emailVerifiedAt: Date | null;
  /** Unverified contact number from profile completion; never used to sign in. */
  contactPhone?: string | null;
  createdAt: Date;
  /** S027 (DEC-PROD-037): soft-deleted at confirm; sessions cannot be issued. */
  deletedAt: Date | null;
  purgeAfter: Date | null;
  purgedAt: Date | null;
};

export type UserProfilePatch = {
  displayName?: string;
  dateOfBirth?: Date | null;
  gender?: UserGenderName | null;
  avatarUrl?: string | null;
  contactPhone?: string | null;
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

export type OpsCredentialRecord = {
  passwordHash: string;
  superAdmin: boolean;
  /** DEC-PROD-043 */
  staffRole: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE';
};

export type OpsSuperAdminChangeInput = {
  targetUserId: string;
  superAdmin: boolean;
  actorUserId: string;
  reason: string;
};

/** `last` = revoking would leave no active super-admin; nothing changed. */
export type OpsSuperAdminChangeResult = 'ok' | 'unchanged' | 'last' | 'no_credential';

export type OpsPasswordResetInput = {
  targetUserId: string;
  passwordHash: string;
  actorUserId: string;
  reason: string;
  at: Date;
};

/** Memory-only mirror of the audit rows the Prisma repository writes (tests). */
export type MemoryOpsAudit = {
  actorUserId: string;
  action:
    | 'OPS_PASSWORD_RESET'
    | 'OPS_SUPER_ADMIN_GRANT'
    | 'OPS_SUPER_ADMIN_REVOKE'
    | 'OPS_STAFF_ROLE_ASSIGN';
  entityId: string;
  reason: string;
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
  deletedAt: Date | null;
  purgeAfter: Date | null;
  purgedAt: Date | null;
  grants: RoleGrantRecord[];
  /** DEC-PROD-043: OpsStaffRole; legacy OPS means no credential yet. */
  staffRole?: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE' | 'OPS';
  /** DEC-PROD-036: may reset other ops passwords. */
  superAdmin?: boolean;
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
  /** Null when the phone had no account at challenge time; set by verify. */
  userId: string | null;
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

export type EmailChallengePurpose = 'SIGNUP' | 'ACTIVATE_EXISTING';

export type EmailSignupChallengeRecord = {
  id: string;
  /** SIGNUP creates a new account; ACTIVATE_EXISTING verifies the email of `userId`. */
  purpose: EmailChallengePurpose;
  userId: string | null;
  email: string;
  /** Null when the address already belonged to an account at challenge time. */
  passwordHash: string | null;
  displayName: string;
  codeHash: string;
  expiresAt: Date;
  attemptCount: number;
  sendCount: number;
  lastSentAt: Date;
  consumedAt: Date | null;
  createdAt: Date;
};

/** DEC-PROD-045 forgot-password code challenge; userId null = decoy for an address with no password. */
export type PasswordResetRecord = {
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
};

export type PasswordResetReissueInput = {
  tokenHash: string;
  expiresAt: Date;
  sentAt: Date;
  sentBefore: Date;
  maxSends: number;
  maxAttempts: number;
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
  deviceLabel: string | null;
  userAgent: string | null;
  ipAddress: string | null;
  lastSeenAt: Date;
  createdAt: Date;
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
  userId: string | null;
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
  deviceLabel?: string | null;
  userAgent?: string | null;
  ipAddress?: string | null;
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
  updateUserProfile(userId: string, patch: UserProfilePatch): Promise<UserRecord>;

  createPhoneChallenge(input: {
    userId: string | null;
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

  createEmailSignupChallenge(input: {
    purpose?: EmailChallengePurpose;
    userId?: string | null;
    email: string;
    passwordHash: string | null;
    displayName: string;
    codeHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<EmailSignupChallengeRecord>;
  findEmailSignupChallenge(id: string): Promise<EmailSignupChallengeRecord | null>;
  /** Newest challenge for the address, regardless of state. */
  findLatestEmailSignupChallenge(email: string): Promise<EmailSignupChallengeRecord | null>;
  countEmailSignupChallengesSince(email: string, since: Date): Promise<number>;
  recordFailedEmailSignupAttempt(id: string): Promise<EmailSignupChallengeRecord>;
  /**
   * Replaces the code only if the challenge is unconsumed, not locked (fewer than
   * `maxAttempts` wrong codes), the last send is at or before `sentBefore` and fewer than
   * `maxSends` codes were sent. Wrong attempts are kept across resends. Returns null otherwise.
   */
  reissueEmailSignupCode(
    id: string,
    input: {
      codeHash: string;
      expiresAt: Date;
      sentAt: Date;
      sentBefore: Date;
      maxSends: number;
      maxAttempts: number;
    },
  ): Promise<EmailSignupChallengeRecord | null>;
  consumeEmailSignupChallenge(id: string, at: Date): Promise<boolean>;
  /** Creates the user (email verified), its password credential and an ACTIVE CUSTOMER grant atomically. */
  createEmailPasswordUser(input: {
    email: string;
    displayName: string;
    passwordHash: string;
    verifiedAt: Date;
  }): Promise<UserRecord>;

  createPasswordReset(input: {
    userId: string | null;
    email: string;
    tokenHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<PasswordResetRecord>;
  findPasswordReset(id: string): Promise<PasswordResetRecord | null>;
  countPasswordResetsSince(email: string, since: Date): Promise<number>;
  recordFailedPasswordResetAttempt(id: string): Promise<PasswordResetRecord>;
  /** Same guards as reissueEmailSignupCode: unconsumed, unlocked, cooldown passed, send cap. */
  reissuePasswordResetCode(
    id: string,
    input: PasswordResetReissueInput,
  ): Promise<PasswordResetRecord | null>;
  /** Consumes only an unconsumed challenge with fewer than `maxAttempts` wrong codes. */
  consumePasswordReset(id: string, at: Date, maxAttempts: number): Promise<boolean>;

  createSession(input: NewSession): Promise<SessionRecord>;
  findSessionById(id: string): Promise<SessionRecord | null>;
  findSessionByRefreshTokenHash(refreshTokenHash: string): Promise<SessionRecord | null>;
  rotateSession(
    refreshTokenHash: string,
    next: { refreshTokenHash: string; expiresAt: Date },
    at: Date,
  ): Promise<RotateResult>;
  revokeSession(id: string, reason: RevokeReasonName, at: Date): Promise<void>;
  listActiveSessions(userId: string): Promise<SessionRecord[]>;
  revokeOtherSessions(userId: string, keepSessionId: string, at: Date): Promise<number>;
  touchSessionMeta(
    id: string,
    meta: { deviceLabel?: string | null; userAgent?: string | null; ipAddress?: string | null },
    at: Date,
  ): Promise<void>;
  revokeUserSessions(userId: string, channel: StoredChannel, at: Date): Promise<void>;
  /** Every live session of the user, customer and ops channels (S027 / S028). */
  revokeAllUserSessions(userId: string, at: Date): Promise<void>;

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
  findOpsCredential(userId: string): Promise<OpsCredentialRecord | null>;
  saveOpsCredential(userId: string, passwordHash: string): Promise<void>;
  /** DEC-PROD-036: flag the bootstrap operator as super-admin (no-op without a credential). */
  setOpsSuperAdmin(userId: string, superAdmin: boolean): Promise<void>;
  setOpsStaffRole(input: {
    targetUserId: string;
    staffRole: OpsCredentialRecord['staffRole'];
    actorUserId: string;
    reason: string;
  }): Promise<'ok' | 'unchanged' | 'no_credential'>;
  /**
   * DEC-PROD-036: one transaction — new password hash, every OPS session of the target
   * revoked (forced re-login), and an `OPS_PASSWORD_RESET` audit row.
   */
  resetOpsPassword(input: OpsPasswordResetInput): Promise<void>;
  /** Grant/revoke under a lock on the super-admin rows; never removes the last one; audited. */
  changeOpsSuperAdmin(input: OpsSuperAdminChangeInput): Promise<OpsSuperAdminChangeResult>;
  findCustomerCredential(userId: string): Promise<{ passwordHash: string } | null>;
  saveCustomerCredential(userId: string, passwordHash: string): Promise<void>;

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
  /** Creates a contact-less CUSTOMER account and its first passkey atomically. */
  createPasskeyUser(input: Omit<Parameters<IdentityRepository['savePasskey']>[0], 'userId'>): Promise<UserRecord>;
  updatePasskeyCounter(id: string, counter: number): Promise<void>;
  replacePasskeyChallenge(input: {
    userId: string | null;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord>;
  findOpenPasskeyChallenge(
    userId: string,
    kind: PasskeyCeremonyName,
  ): Promise<PasskeyChallengeRecord | null>;
  findPasskeyChallenge(id: string): Promise<PasskeyChallengeRecord | null>;
  consumePasskeyChallenge(id: string, at: Date): Promise<boolean>;
}

export class MemoryIdentityRepository implements IdentityRepository {
  private readonly users = new Map<string, UserRecord>();
  private readonly grants = new Map<string, RoleGrantRecord[]>();
  private readonly phoneChallenges = new Map<string, PhoneChallengeRecord>();
  private readonly emailVerifications = new Map<string, EmailVerificationRecord>();
  private readonly passwordResets = new Map<string, PasswordResetRecord>();
  private readonly emailSignups = new Map<string, EmailSignupChallengeRecord>();
  private readonly sessions = new Map<string, SessionRecord>();
  private readonly credentials = new Map<string, OpsCredentialRecord>();
  readonly opsAudits: MemoryOpsAudit[] = [];
  private readonly customerCredentials = new Map<string, { passwordHash: string }>();
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
      dateOfBirth: null,
      gender: null,
      avatarUrl: null,
      phoneVerifiedAt: null,
      emailVerifiedAt: null,
      createdAt: new Date(),
      deletedAt: null,
      purgeAfter: null,
      purgedAt: null,
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

  async updateUserProfile(userId: string, patch: UserProfilePatch): Promise<UserRecord> {
    const user = this.requireUser(userId);
    if (patch.displayName !== undefined) {
      user.displayName = patch.displayName;
    }
    if (patch.dateOfBirth !== undefined) {
      user.dateOfBirth = patch.dateOfBirth;
    }
    if (patch.gender !== undefined) {
      user.gender = patch.gender;
    }
    if (patch.contactPhone !== undefined) {
      user.contactPhone = patch.contactPhone;
    }
    if (patch.avatarUrl !== undefined) {
      user.avatarUrl = patch.avatarUrl;
    }
    return user;
  }

  async createPhoneChallenge(input: {
    userId: string | null;
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
    const challenge: EmailSignupChallengeRecord = {
      id: randomUUID(),
      purpose: input.purpose ?? 'SIGNUP',
      userId: input.userId ?? null,
      email: input.email,
      passwordHash: input.passwordHash,
      displayName: input.displayName,
      codeHash: input.codeHash,
      expiresAt: input.expiresAt,
      attemptCount: 0,
      sendCount: 1,
      lastSentAt: input.sentAt,
      consumedAt: null,
      createdAt: new Date(),
    };
    this.emailSignups.set(challenge.id, challenge);
    return { ...challenge };
  }

  async findEmailSignupChallenge(id: string): Promise<EmailSignupChallengeRecord | null> {
    const challenge = this.emailSignups.get(id);
    return challenge ? { ...challenge } : null;
  }

  async findLatestEmailSignupChallenge(
    email: string,
  ): Promise<EmailSignupChallengeRecord | null> {
    let latest: EmailSignupChallengeRecord | null = null;
    for (const challenge of this.emailSignups.values()) {
      if (challenge.email === email && (!latest || challenge.createdAt >= latest.createdAt)) {
        latest = challenge;
      }
    }
    return latest ? { ...latest } : null;
  }

  async countEmailSignupChallengesSince(email: string, since: Date): Promise<number> {
    return [...this.emailSignups.values()].filter(
      (challenge) => challenge.email === email && challenge.createdAt >= since,
    ).length;
  }

  async recordFailedEmailSignupAttempt(id: string): Promise<EmailSignupChallengeRecord> {
    const challenge = this.emailSignups.get(id);
    if (!challenge) {
      throw new Error('Email signup challenge not found');
    }
    challenge.attemptCount += 1;
    return { ...challenge };
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
    const challenge = this.emailSignups.get(id);
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.attemptCount >= input.maxAttempts ||
      challenge.lastSentAt > input.sentBefore ||
      challenge.sendCount >= input.maxSends
    ) {
      return null;
    }
    challenge.codeHash = input.codeHash;
    challenge.expiresAt = input.expiresAt;
    challenge.lastSentAt = input.sentAt;
    challenge.sendCount += 1;
    return { ...challenge };
  }

  async consumeEmailSignupChallenge(id: string, at: Date): Promise<boolean> {
    const challenge = this.emailSignups.get(id);
    if (!challenge || challenge.consumedAt) {
      return false;
    }
    challenge.consumedAt = at;
    return true;
  }

  async createEmailPasswordUser(input: {
    email: string;
    displayName: string;
    passwordHash: string;
    verifiedAt: Date;
  }): Promise<UserRecord> {
    const user = await this.createUser({
      email: input.email,
      phone: null,
      displayName: input.displayName,
    });
    user.emailVerifiedAt = input.verifiedAt;
    this.customerCredentials.set(user.id, { passwordHash: input.passwordHash });
    await this.insertGrant(user.id, 'CUSTOMER', 'ACTIVE');
    return user;
  }

  async createPasswordReset(input: {
    userId: string | null;
    email: string;
    tokenHash: string;
    expiresAt: Date;
    sentAt: Date;
  }): Promise<PasswordResetRecord> {
    const reset: PasswordResetRecord = {
      id: randomUUID(),
      userId: input.userId,
      email: input.email,
      tokenHash: input.tokenHash,
      expiresAt: input.expiresAt,
      attemptCount: 0,
      sendCount: 1,
      lastSentAt: input.sentAt,
      consumedAt: null,
      createdAt: input.sentAt,
    };
    this.passwordResets.set(reset.id, reset);
    return { ...reset };
  }

  async findPasswordReset(id: string): Promise<PasswordResetRecord | null> {
    const reset = this.passwordResets.get(id);
    return reset ? { ...reset } : null;
  }

  async countPasswordResetsSince(email: string, since: Date): Promise<number> {
    return [...this.passwordResets.values()].filter(
      (reset) => reset.email === email && reset.createdAt >= since,
    ).length;
  }

  async recordFailedPasswordResetAttempt(id: string): Promise<PasswordResetRecord> {
    const reset = this.passwordResets.get(id);
    if (!reset) {
      throw new Error('Password reset not found');
    }
    reset.attemptCount += 1;
    return { ...reset };
  }

  async reissuePasswordResetCode(
    id: string,
    input: PasswordResetReissueInput,
  ): Promise<PasswordResetRecord | null> {
    const reset = this.passwordResets.get(id);
    if (
      !reset ||
      reset.consumedAt ||
      reset.attemptCount >= input.maxAttempts ||
      reset.lastSentAt > input.sentBefore ||
      reset.sendCount >= input.maxSends
    ) {
      return null;
    }
    reset.tokenHash = input.tokenHash;
    reset.expiresAt = input.expiresAt;
    reset.lastSentAt = input.sentAt;
    reset.sendCount += 1;
    return { ...reset };
  }

  async consumePasswordReset(id: string, at: Date, maxAttempts: number): Promise<boolean> {
    const reset = this.passwordResets.get(id);
    if (!reset || reset.consumedAt || reset.attemptCount >= maxAttempts) {
      return false;
    }
    reset.consumedAt = at;
    return true;
  }

  async createSession(input: NewSession): Promise<SessionRecord> {
    const now = new Date();
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
      deviceLabel: input.deviceLabel ?? null,
      userAgent: input.userAgent ?? null,
      ipAddress: input.ipAddress ?? null,
      lastSeenAt: now,
      createdAt: now,
    };
    this.sessions.set(session.id, session);
    return session;
  }

  async listActiveSessions(userId: string): Promise<SessionRecord[]> {
    return [...this.sessions.values()].filter((s) => s.userId === userId && !s.revokedAt);
  }

  async revokeOtherSessions(userId: string, keepSessionId: string, at: Date): Promise<number> {
    let n = 0;
    for (const session of this.sessions.values()) {
      if (session.userId !== userId || session.id === keepSessionId || session.revokedAt) continue;
      session.revokedAt = at;
      session.revokeReason = 'USER';
      n += 1;
    }
    return n;
  }

  async touchSessionMeta(
    id: string,
    meta: { deviceLabel?: string | null; userAgent?: string | null; ipAddress?: string | null },
    at: Date,
  ): Promise<void> {
    const session = this.sessions.get(id);
    if (!session || session.revokedAt) return;
    if (meta.deviceLabel !== undefined) session.deviceLabel = meta.deviceLabel;
    if (meta.userAgent !== undefined) session.userAgent = meta.userAgent;
    if (meta.ipAddress !== undefined) session.ipAddress = meta.ipAddress;
    session.lastSeenAt = at;
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
      deviceLabel: current.deviceLabel,
      userAgent: current.userAgent,
      ipAddress: current.ipAddress,
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

  async revokeUserSessions(userId: string, channel: StoredChannel, at: Date): Promise<void> {
    for (const session of this.sessions.values()) {
      if (session.userId === userId && session.channel === channel && !session.revokedAt) {
        session.revokedAt = at;
        session.revokeReason = 'USER';
      }
    }
  }

  async revokeAllUserSessions(userId: string, at: Date): Promise<void> {
    for (const session of this.sessions.values()) {
      if (session.userId === userId && !session.revokedAt) {
        session.revokedAt = at;
        session.revokeReason = 'USER';
      }
    }
  }

  /** Memory twin of the Prisma account-deletion transaction (tests / no DATABASE_URL). */
  async softDeleteUser(userId: string, at: Date, purgeAfter: Date): Promise<void> {
    const user = this.users.get(userId);
    if (user) {
      user.deletedAt = at;
      user.purgeAfter = purgeAfter;
    }
    await this.revokeAllUserSessions(userId, at);
  }

  async restoreUser(userId: string): Promise<void> {
    const user = this.users.get(userId);
    if (user && !user.purgedAt) {
      user.deletedAt = null;
      user.purgeAfter = null;
    }
  }

  async anonymizeUser(userId: string, displayName: string, at: Date): Promise<void> {
    const user = this.users.get(userId);
    if (!user) {
      return;
    }
    Object.assign(user, {
      email: null,
      phone: null,
      displayName,
      dateOfBirth: null,
      gender: null,
      avatarUrl: null,
      phoneVerifiedAt: null,
      emailVerifiedAt: null,
      purgedAt: at,
    });
    this.customerCredentials.delete(userId);
    for (const [id, passkey] of this.passkeys) {
      if (passkey.userId === userId) {
        this.passkeys.delete(id);
      }
    }
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
        deletedAt: user.deletedAt,
        purgeAfter: user.purgeAfter,
        purgedAt: user.purgedAt,
        grants: grants.map((grant) => ({ ...grant })),
        staffRole:
          role === 'OPS'
            ? (this.credentials.get(user.id)?.staffRole ?? 'OPS')
            : undefined,
        superAdmin: role === 'OPS' ? this.credentials.get(user.id)?.superAdmin === true : undefined,
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
      deletedAt: user.deletedAt,
      purgeAfter: user.purgeAfter,
      purgedAt: user.purgedAt,
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

  async findOpsCredential(userId: string): Promise<OpsCredentialRecord | null> {
    const credential = this.credentials.get(userId);
    return credential ? { ...credential } : null;
  }

  async saveOpsCredential(userId: string, passwordHash: string): Promise<void> {
    const prev = this.credentials.get(userId);
    this.credentials.set(userId, {
      passwordHash,
      superAdmin: prev?.superAdmin ?? false,
      staffRole: prev?.staffRole ?? 'ADMIN',
    });
  }

  async setOpsStaffRole(input: {
    targetUserId: string;
    staffRole: OpsCredentialRecord['staffRole'];
    actorUserId: string;
    reason: string;
  }): Promise<'ok' | 'unchanged' | 'no_credential'> {
    const credential = this.credentials.get(input.targetUserId);
    if (!credential) return 'no_credential';
    if (credential.staffRole === input.staffRole) return 'unchanged';
    const previous = credential.staffRole;
    credential.staffRole = input.staffRole;
    this.opsAudits.push({
      actorUserId: input.actorUserId,
      action: 'OPS_STAFF_ROLE_ASSIGN',
      entityId: input.targetUserId,
      reason: input.reason,
    });
    void previous;
    return 'ok';
  }

  async setOpsSuperAdmin(userId: string, superAdmin: boolean): Promise<void> {
    const credential = this.credentials.get(userId);
    if (credential) {
      credential.superAdmin = superAdmin;
    }
  }

  async resetOpsPassword(input: OpsPasswordResetInput): Promise<void> {
    const credential = this.credentials.get(input.targetUserId);
    if (!credential) {
      throw new Error('OPS_NO_PASSWORD_LOGIN');
    }
    credential.passwordHash = input.passwordHash;
    await this.revokeUserSessions(input.targetUserId, 'OPS', input.at);
    this.opsAudits.push({
      actorUserId: input.actorUserId,
      action: 'OPS_PASSWORD_RESET',
      entityId: input.targetUserId,
      reason: input.reason,
    });
  }

  async changeOpsSuperAdmin(input: OpsSuperAdminChangeInput): Promise<OpsSuperAdminChangeResult> {
    const credential = this.credentials.get(input.targetUserId);
    if (!credential?.passwordHash) {
      return 'no_credential';
    }
    if (credential.superAdmin === input.superAdmin) {
      return 'unchanged';
    }
    if (!input.superAdmin) {
      const others = [...this.credentials.entries()].filter(
        ([userId, entry]) =>
          entry.superAdmin &&
          userId !== input.targetUserId &&
          (this.grants.get(userId) ?? []).some((g) => g.role === 'OPS' && g.status === 'ACTIVE'),
      );
      if (others.length === 0) {
        return 'last';
      }
    }
    credential.superAdmin = input.superAdmin;
    this.opsAudits.push({
      actorUserId: input.actorUserId,
      action: input.superAdmin ? 'OPS_SUPER_ADMIN_GRANT' : 'OPS_SUPER_ADMIN_REVOKE',
      entityId: input.targetUserId,
      reason: input.reason,
    });
    return 'ok';
  }

  async findCustomerCredential(userId: string): Promise<{ passwordHash: string } | null> {
    return this.customerCredentials.get(userId) ?? null;
  }

  async saveCustomerCredential(userId: string, passwordHash: string): Promise<void> {
    this.customerCredentials.set(userId, { passwordHash });
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

  async createPasskeyUser(
    input: Omit<Parameters<IdentityRepository['savePasskey']>[0], 'userId'>,
  ): Promise<UserRecord> {
    const user = await this.createUser({ email: null, phone: null, displayName: 'DealGo user' });
    await this.insertGrant(user.id, 'CUSTOMER', 'ACTIVE');
    await this.savePasskey({ ...input, userId: user.id });
    return user;
  }

  async replacePasskeyChallenge(input: {
    userId: string | null;
    kind: PasskeyCeremonyName;
    challenge: string;
    expiresAt: Date;
  }): Promise<PasskeyChallengeRecord> {
    const at = new Date();
    for (const existing of this.passkeyChallenges.values()) {
      if (input.userId !== null && existing.userId === input.userId && existing.kind === input.kind && !existing.consumedAt) {
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

  async findPasskeyChallenge(id: string): Promise<PasskeyChallengeRecord | null> {
    return this.passkeyChallenges.get(id) ?? null;
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
