import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DEV_OPS_BOOTSTRAP_PASSWORD, type AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import { UniqueConflictError, type IdentityRepository, type UserRecord } from './identity.repository.js';
import { normalizeEmail } from './phone-number.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { SessionService, type SessionResult } from './session.service.js';

@Injectable()
export class OpsAuthService implements OnModuleInit {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly sessions: SessionService,
    private readonly passwords: PasswordHasher,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  private readonly logger = new Logger(OpsAuthService.name);

  async onModuleInit(): Promise<void> {
    const email = this.config.get('OPS_BOOTSTRAP_EMAIL', { infer: true });
    const password = this.config.get('OPS_BOOTSTRAP_PASSWORD', { infer: true });
    if (!email || !password) {
      return;
    }
    try {
      await this.ensureOperator(email, password, this.config.get('NODE_ENV', { infer: true }));
    } catch (err) {
      this.logger.warn({
        msg: 'ops.bootstrap_skipped',
        detail: err instanceof Error ? err.message : String(err),
      });
    }
  }

  async ensureOperator(
    rawEmail: string,
    password: string,
    nodeEnv: AppEnv['NODE_ENV'],
  ): Promise<UserRecord> {
    if (nodeEnv === 'production' && password === DEV_OPS_BOOTSTRAP_PASSWORD) {
      throw new Error(
        'OPS_BOOTSTRAP_PASSWORD must not be change-me-dev-only when NODE_ENV=production',
      );
    }

    const email = normalizeEmail(rawEmail);
    const existing = await this.repository.findUserByEmail(email);
    if (!existing) {
      const user = await this.repository.createUser({
        email,
        phone: null,
        displayName: 'DealGo ops',
      });
      await this.repository.saveOpsCredential(user.id, await this.passwords.hash(password));
      await this.ensureActiveOpsGrant(user.id);
      return user;
    }

    const credential = await this.repository.findOpsCredential(existing.id);
    if (!credential) {
      await this.repository.saveOpsCredential(existing.id, await this.passwords.hash(password));
    }
    await this.ensureActiveOpsGrant(existing.id);
    return existing;
  }

  async login(rawEmail: string, password: string): Promise<SessionResult> {
    const email = normalizeEmail(rawEmail);
    const user = await this.repository.findUserByEmail(email);
    const credential = user ? await this.repository.findOpsCredential(user.id) : null;
    const grants = user ? await this.repository.listGrants(user.id) : [];
    const opsActive = grants.some((grant) => grant.role === 'OPS' && grant.status === 'ACTIVE');
    const passwordMatches = await this.passwords.verifyPresented(credential?.passwordHash ?? null, password);
    if (!user || !opsActive || !passwordMatches) {
      throw authError(401, 'AUTH_INVALID_CREDENTIALS', 'Invalid email or password');
    }
    return this.sessions.issue(user, 'ops');
  }

  private async ensureActiveOpsGrant(userId: string): Promise<void> {
    const grants = await this.repository.listGrants(userId);
    if (grants.some((grant) => grant.role === 'OPS')) {
      return;
    }
    try {
      await this.repository.insertGrant(userId, 'OPS', 'ACTIVE');
    } catch (error) {
      if (!(error instanceof UniqueConflictError)) {
        throw error;
      }
    }
  }
}
