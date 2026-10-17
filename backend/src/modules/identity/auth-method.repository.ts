import { randomUUID } from 'node:crypto';
import { AUTH_METHODS, type AuthMethodName } from './auth-method.constants.js';

export type AuthMethodPolicyRecord = {
  id: string;
  method: AuthMethodName;
  enabled: boolean;
  updatedAt: Date;
  updatedByUserId: string | null;
};

export type AuthMethodPolicyUpdateInput = {
  method: AuthMethodName;
  enabled: boolean;
  updatedByUserId: string;
  reason: string;
};

export interface AuthMethodPolicyRepository {
  ensureDefaults(): Promise<AuthMethodPolicyRecord[]>;
  list(): Promise<AuthMethodPolicyRecord[]>;
  findByMethod(method: AuthMethodName): Promise<AuthMethodPolicyRecord | null>;
  setEnabled(input: AuthMethodPolicyUpdateInput): Promise<AuthMethodPolicyRecord | null>;
}

export class MemoryAuthMethodPolicyRepository implements AuthMethodPolicyRepository {
  private readonly policies = new Map<AuthMethodName, AuthMethodPolicyRecord>();
  readonly audits: Array<{
    actorUserId: string;
    method: AuthMethodName;
    enabled: boolean;
    reason: string;
  }> = [];

  async ensureDefaults(): Promise<AuthMethodPolicyRecord[]> {
    const now = new Date();
    for (const method of AUTH_METHODS) {
      if (!this.policies.has(method)) {
        this.policies.set(method, {
          id: randomUUID(),
          method,
          enabled: true,
          updatedAt: now,
          updatedByUserId: null,
        });
      }
    }
    return AUTH_METHODS.map((method) => this.policies.get(method)!);
  }

  async list(): Promise<AuthMethodPolicyRecord[]> {
    return this.ensureDefaults();
  }

  async findByMethod(method: AuthMethodName): Promise<AuthMethodPolicyRecord | null> {
    await this.ensureDefaults();
    return this.policies.get(method) ?? null;
  }

  async setEnabled(input: AuthMethodPolicyUpdateInput): Promise<AuthMethodPolicyRecord | null> {
    await this.ensureDefaults();
    const current = this.policies.get(input.method);
    if (!current) {
      return null;
    }

    if (!input.enabled) {
      const enabledCount = [...this.policies.values()].filter((p) => p.enabled).length;
      if (current.enabled && enabledCount <= 1) {
        return null;
      }
    }

    const updated: AuthMethodPolicyRecord = {
      ...current,
      enabled: input.enabled,
      updatedAt: new Date(),
      updatedByUserId: input.updatedByUserId,
    };
    this.policies.set(input.method, updated);
    this.audits.push({
      actorUserId: input.updatedByUserId,
      method: input.method,
      enabled: input.enabled,
      reason: input.reason,
    });
    return updated;
  }
}
