import { Inject, Injectable } from '@nestjs/common';
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
};

@Injectable()
export class AuthMethodPolicyService {
  constructor(
    @Inject(AUTH_METHOD_POLICY_REPOSITORY)
    private readonly policies: AuthMethodPolicyRepository,
  ) {}

  async list(): Promise<AuthMethodPolicyView[]> {
    const rows = await this.policies.list();
    return rows.map(toView);
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
    return toView(updated);
  }

  async assertEnabled(method: AuthMethodName): Promise<void> {
    const policy = await this.policies.findByMethod(method);
    if (!policy?.enabled) {
      throw authError(403, 'AUTH_METHOD_DISABLED', `Auth method ${method} is disabled`);
    }
  }
}

function toView(row: AuthMethodPolicyRecord): AuthMethodPolicyView {
  return {
    method: row.method,
    enabled: row.enabled,
    updatedAt: row.updatedAt.toISOString(),
    updatedByUserId: row.updatedByUserId,
  };
}
