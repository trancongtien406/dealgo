import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { AUTH_METHODS, type AuthMethodName } from './auth-method.constants.js';
import type {
  AuthMethodPolicyRecord,
  AuthMethodPolicyRepository,
  AuthMethodPolicyUpdateInput,
} from './auth-method.repository.js';

export class PrismaAuthMethodPolicyRepository implements AuthMethodPolicyRepository {
  constructor(private readonly db: PrismaClient) {}

  async ensureDefaults(): Promise<AuthMethodPolicyRecord[]> {
    for (const method of AUTH_METHODS) {
      await this.db.authMethodPolicy.upsert({
        where: { method },
        create: {
          id: randomUUID(),
          method,
          enabled: true,
        },
        update: {},
      });
    }
    const rows = await this.db.authMethodPolicy.findMany();
    const byMethod = new Map(rows.map((row) => [row.method as AuthMethodName, mapPolicy(row)]));
    return AUTH_METHODS.map((method) => byMethod.get(method)!);
  }

  async list(): Promise<AuthMethodPolicyRecord[]> {
    return this.ensureDefaults();
  }

  async findByMethod(method: AuthMethodName): Promise<AuthMethodPolicyRecord | null> {
    await this.ensureDefaults();
    const row = await this.db.authMethodPolicy.findUnique({ where: { method } });
    return row ? mapPolicy(row) : null;
  }

  async setEnabled(input: AuthMethodPolicyUpdateInput): Promise<AuthMethodPolicyRecord | null> {
    return this.db.$transaction(async (tx) => {
      for (const method of AUTH_METHODS) {
        await tx.authMethodPolicy.upsert({
          where: { method },
          create: {
            id: randomUUID(),
            method,
            enabled: true,
          },
          update: {},
        });
      }

      const current = await tx.authMethodPolicy.findUnique({ where: { method: input.method } });
      if (!current) {
        return null;
      }

      if (!input.enabled && current.enabled) {
        const enabledCount = await tx.authMethodPolicy.count({ where: { enabled: true } });
        if (enabledCount <= 1) {
          return null;
        }
      }

      const updated = await tx.authMethodPolicy.update({
        where: { method: input.method },
        data: {
          enabled: input.enabled,
          updatedByUserId: input.updatedByUserId,
        },
      });

      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.updatedByUserId,
          action: 'AUTH_METHOD_UPDATE',
          entityType: 'AUTH_METHOD_POLICY',
          entityId: updated.id,
          reason: input.reason,
          metadata: {
            method: input.method,
            enabled: input.enabled,
            previousEnabled: current.enabled,
          },
        },
      });

      return mapPolicy(updated);
    });
  }
}

function mapPolicy(row: {
  id: string;
  method: string;
  enabled: boolean;
  updatedAt: Date;
  updatedByUserId: string | null;
}): AuthMethodPolicyRecord {
  return {
    id: row.id,
    method: row.method as AuthMethodName,
    enabled: row.enabled,
    updatedAt: row.updatedAt,
    updatedByUserId: row.updatedByUserId,
  };
}
