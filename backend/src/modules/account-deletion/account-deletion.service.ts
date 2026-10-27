import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import {
  accessSecret,
  fixedEqual,
  hashOneTimeSecret,
  randomOtpCode,
} from '../../platform/security/token-crypto.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { maskPhone } from '../../shared/privacy/pii-mask.js';
import type { SmsSender } from '../../integrations/sms/sms-sender.js';
import { authError } from '../identity/auth-error.js';
import {
  IDENTITY_REPOSITORY,
  MAX_PHONE_ATTEMPTS,
  PHONE_CHALLENGE_TTL_MS,
  SMS_SENDER,
} from '../identity/identity.constants.js';
import type { IdentityRepository, UserRecord } from '../identity/identity.repository.js';
import {
  ACCOUNT_DELETION_REPOSITORY,
  type AccountDeletionBlocker,
  type AccountDeletionMethodName,
  type AccountDeletionRepository,
  type AccountDeletionStatusName,
} from './account-deletion.repository.js';

const DAY_MS = 24 * 60 * 60 * 1000;
/** A password re-auth request stays usable as long as an OTP one. */
const REQUEST_TTL_MS = PHONE_CHALLENGE_TTL_MS;

export type AccountDeletionOverview = {
  status: AccountDeletionStatusName | 'NONE';
  graceDays: number;
  method: AccountDeletionMethodName | null;
  phoneMasked: string | null;
  blockers: AccountDeletionBlocker[];
  purgeAfter: string | null;
};

/**
 * S027 account deletion (DEC-PROD-037): request → re-auth (SMS OTP to the verified phone, or
 * the account password) → soft-delete + revoke every session → purge worker anonymizes PII
 * after ACCOUNT_DELETION_GRACE_DAYS. Ops can restore during the grace period (audited).
 */
@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(
    @Inject(ACCOUNT_DELETION_REPOSITORY) private readonly repository: AccountDeletionRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    private readonly passwords: PasswordHasher,
    private readonly settings: PlatformSettingsService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async overview(userId: string): Promise<AccountDeletionOverview> {
    const user = await this.requireUser(userId);
    const [latest, blockers, graceDays, method] = await Promise.all([
      this.repository.findLatest(userId),
      this.repository.findBlockers(userId),
      this.graceDays(),
      this.methodFor(user),
    ]);
    return {
      status: latest?.status ?? 'NONE',
      graceDays,
      method,
      phoneMasked: method === 'PHONE_OTP' ? maskPhone(user.phone) : null,
      blockers,
      purgeAfter: latest?.purgeAfter?.toISOString() ?? null,
    };
  }

  async start(userId: string): Promise<{
    requestId: string;
    method: AccountDeletionMethodName;
    expiresAt: string;
    phoneMasked: string | null;
    graceDays: number;
  }> {
    const user = await this.requireUser(userId);
    await this.assertNoBlockers(userId);
    const method = await this.methodFor(user);
    if (!method) {
      throw authError(
        409,
        'ACCOUNT_DELETION_REAUTH_UNAVAILABLE',
        'Add a verified phone or a password before deleting the account',
      );
    }
    const code = method === 'PHONE_OTP' ? randomOtpCode() : null;
    const expiresAt = new Date(Date.now() + REQUEST_TTL_MS);
    const request = await this.repository.createRequest({
      userId,
      method,
      codeHash: code ? hashOneTimeSecret(code, this.pepper()) : null,
      expiresAt,
    });
    if (code && user.phone) {
      await this.sms.sendOtp(user.phone, code);
    }
    return {
      requestId: request.id,
      method,
      expiresAt: expiresAt.toISOString(),
      phoneMasked: method === 'PHONE_OTP' ? maskPhone(user.phone) : null,
      graceDays: await this.graceDays(),
    };
  }

  async confirm(
    userId: string,
    requestId: string,
    proof: { code?: string; password?: string },
  ): Promise<{ status: 'SCHEDULED'; purgeAfter: string; graceDays: number }> {
    const request = await this.repository.findRequest(requestId);
    if (!request || request.userId !== userId || request.status !== 'PENDING') {
      throw authError(404, 'ACCOUNT_DELETION_NOT_FOUND', 'Deletion request not found');
    }
    if (request.attemptCount >= MAX_PHONE_ATTEMPTS) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Too many wrong attempts; start again');
    }
    if (request.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_CODE_EXPIRED', 'The deletion request has expired; start again');
    }
    const ok = await this.verifyProof(userId, request.method, request.codeHash, proof);
    if (!ok) {
      const updated = await this.repository.recordFailedAttempt(request.id);
      if (updated.attemptCount >= MAX_PHONE_ATTEMPTS) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Too many wrong attempts; start again');
      }
      throw request.method === 'PHONE_OTP'
        ? authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid')
        : authError(401, 'AUTH_PASSWORD_INVALID', 'Password is incorrect');
    }
    const graceDays = await this.graceDays();
    const at = new Date();
    const result = await this.repository.confirm({
      requestId,
      userId,
      at,
      purgeAfter: new Date(at.getTime() + graceDays * DAY_MS),
    });
    if (result.status === 'blocked') {
      throw blockedError(result.blockers);
    }
    if (result.status === 'stale') {
      throw authError(404, 'ACCOUNT_DELETION_NOT_FOUND', 'Deletion request not found');
    }
    this.logger.log({ msg: 'account_deletion.scheduled', userId, graceDays });
    return {
      status: 'SCHEDULED',
      purgeAfter: result.record.purgeAfter!.toISOString(),
      graceDays,
    };
  }

  async cancelByOps(input: {
    actorUserId: string;
    userId: string;
    reason: string;
  }): Promise<{ userId: string; status: 'CANCELLED' }> {
    const record = await this.repository.cancelScheduled({
      userId: input.userId,
      actorUserId: input.actorUserId,
      reason: input.reason.trim(),
      at: new Date(),
    });
    if (!record) {
      throw authError(
        409,
        'ACCOUNT_DELETION_NOT_SCHEDULED',
        'No deletion in its grace period for this user',
      );
    }
    return { userId: input.userId, status: 'CANCELLED' };
  }

  async driverFeeBalance(driverId: string): Promise<{ amountVnd: number; settledThrough: string | null }> {
    await this.requireUser(driverId);
    const balance = await this.repository.driverFeeBalance(driverId);
    return {
      amountVnd: balance.amountVnd,
      settledThrough: balance.settledThrough?.toISOString() ?? null,
    };
  }

  async settleDriverFees(input: {
    actorUserId: string;
    driverId: string;
    reason: string;
  }): Promise<{ amountVnd: number; settledThrough: string }> {
    await this.requireUser(input.driverId);
    const settled = await this.repository.settleDriverFees({
      driverId: input.driverId,
      actorUserId: input.actorUserId,
      reason: input.reason.trim(),
      at: new Date(),
    });
    if (!settled) {
      throw authError(409, 'DRIVER_FEE_NOTHING_OUTSTANDING', 'No unsettled platform fee');
    }
    return { amountVnd: settled.amountVnd, settledThrough: settled.settledThrough.toISOString() };
  }

  async recordDriverPayment(input: {
    actorUserId: string;
    driverId: string;
    direction: 'DRIVER_PAID' | 'DEALGO_PAID';
    amountVnd: number;
    reason: string;
  }): Promise<{ id: string; adjustmentVnd: number }> {
    await this.requireUser(input.driverId);
    return this.repository.recordDriverPayment({ ...input, reason: input.reason.trim(), at: new Date() });
  }

  /** Purge worker: anonymize accounts whose grace period has ended. Returns how many. */
  async purgeDue(now = new Date(), limit = 50): Promise<number> {
    const due = await this.repository.listDue(now, limit);
    let purged = 0;
    for (const request of due) {
      if (await this.repository.purge(request.id, now)) {
        purged += 1;
      }
    }
    if (purged > 0) {
      this.logger.log({ msg: 'account_deletion.purged', count: purged });
    }
    return purged;
  }

  private async assertNoBlockers(userId: string): Promise<void> {
    const blockers = await this.repository.findBlockers(userId);
    if (blockers.length > 0) {
      throw blockedError(blockers);
    }
  }

  private async verifyProof(
    userId: string,
    method: AccountDeletionMethodName,
    codeHash: string | null,
    proof: { code?: string; password?: string },
  ): Promise<boolean> {
    if (method === 'PHONE_OTP') {
      return (
        !!proof.code &&
        !!codeHash &&
        fixedEqual(hashOneTimeSecret(proof.code, this.pepper()), codeHash)
      );
    }
    const credential = await this.identity.findCustomerCredential(userId);
    return (
      !!proof.password &&
      !!credential?.passwordHash &&
      (await this.passwords.verify(credential.passwordHash, proof.password))
    );
  }

  private async methodFor(user: UserRecord): Promise<AccountDeletionMethodName | null> {
    if (user.phone && user.phoneVerifiedAt) {
      return 'PHONE_OTP';
    }
    const credential = await this.identity.findCustomerCredential(user.id);
    return credential?.passwordHash ? 'PASSWORD' : null;
  }

  private async requireUser(userId: string): Promise<UserRecord> {
    const user = await this.identity.findUserById(userId);
    if (!user) {
      throw authError(404, 'USER_NOT_FOUND', 'User not found');
    }
    return user;
  }

  private async graceDays(): Promise<number> {
    return this.settings.getNumber('ACCOUNT_DELETION_GRACE_DAYS');
  }

  private pepper(): string {
    return accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
  }
}

function blockedError(blockers: AccountDeletionBlocker[]) {
  return authError(409, 'ACCOUNT_DELETION_BLOCKED', 'Finish or settle these first', {
    blockers,
  });
}
