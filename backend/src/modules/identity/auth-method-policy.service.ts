import { Inject, Injectable, NotFoundException, Optional } from '@nestjs/common';
import { AuthMethodProviderStatus } from './auth-method-providers.js';
import { authError } from './auth-error.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  isAuthMethodName,
  type AuthMethodName,
} from './auth-method.constants.js';
import type {
  AuthMethodPolicyRecord,
  AuthMethodPolicyRepository,
} from './auth-method.repository.js';

export type AuthMethodPolicyView = {
  method: AuthMethodName;
  enabled: boolean;
  updatedAt: string;
  updatedByUserId: string | null;
  /** False when the method has no ready provider (email: configured + test passed); enabling it is refused. */
  providerReady: boolean;
};

/** Public view: only the method name; disabled methods are left out entirely. */
export type PublicAuthMethodView = { method: AuthMethodName };

/**
 * What a disabled method's endpoint answers: the same 404 an unknown route gets, so callers
 * cannot tell a disabled method from one that does not exist (no method name, no special code).
 */
export function authMethodUnavailable(httpMethod = 'POST', path = ''): NotFoundException {
  return new NotFoundException(path ? `Cannot ${httpMethod} ${path}` : 'Not Found');
}

@Injectable()
export class AuthMethodPolicyService {
  constructor(
    @Inject(AUTH_METHOD_POLICY_REPOSITORY)
    private readonly policies: AuthMethodPolicyRepository,
    @Optional() private readonly providers?: AuthMethodProviderStatus,
  ) {}

  /** Ops-only full list (flags, audit fields, provider readiness). */
  async list(): Promise<AuthMethodPolicyView[]> {
    const rows = await this.policies.list();
    return Promise.all(rows.map(async (row) => toView(row, await this.providerReady(row.method))));
  }

  /** Public list for sign-in screens: enabled methods only, nothing else about them. */
  async listPublic(): Promise<PublicAuthMethodView[]> {
    const rows = await this.policies.list();
    return rows.filter((row) => row.enabled).map((row) => ({ method: row.method }));
  }

  async isEnabled(method: AuthMethodName): Promise<boolean> {
    return Boolean((await this.policies.findByMethod(method))?.enabled);
  }

  private async providerReady(method: AuthMethodName): Promise<boolean> {
    return this.providers ? this.providers.isAvailable(method, 'enable') : true;
  }

  async setEnabled(
    rawMethod: string,
    enabled: boolean,
    reason: string,
    actorUserId: string,
  ): Promise<AuthMethodPolicyView> {
    if (!isAuthMethodName(rawMethod)) {
      throw authError(400, 'VALIDATION_ERROR', 'Unknown auth method');
    }
    if (enabled && !(await this.providerReady(rawMethod))) {
      throw authError(
        409,
        'AUTH_METHOD_PROVIDER_UNAVAILABLE',
        `Auth method ${rawMethod} has no configured provider`,
      );
    }

    const updated = await this.policies.setEnabled({
      method: rawMethod,
      enabled,
      updatedByUserId: actorUserId,
      reason,
    });
    if (!updated) {
      throw authError(
        409,
        'AUTH_METHOD_LAST_ENABLED',
        'At least one auth method must remain enabled',
      );
    }
    return toView(updated, await this.providerReady(updated.method));
  }

  /** Service-level backstop behind AuthMethodEnabledGuard (method switched off mid-request). */
  async assertEnabled(method: AuthMethodName): Promise<void> {
    if (!(await this.isEnabled(method))) {
      throw authMethodUnavailable();
    }
  }
}

function toView(row: AuthMethodPolicyRecord, providerReady: boolean): AuthMethodPolicyView {
  return {
    method: row.method,
    enabled: row.enabled,
    updatedAt: row.updatedAt.toISOString(),
    updatedByUserId: row.updatedByUserId,
    providerReady,
  };
}
