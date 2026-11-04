import { randomUUID } from 'node:crypto';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

export type IntegrationKindName = 'EMAIL' | 'MAPS' | 'SENTRY' | 'STORAGE' | 'SMS';

/** Non-secret fields as strings; secrets stay in `secretsCiphertext` (see SecretBox). */
export type IntegrationSettingRecord = {
  id: string;
  kind: IntegrationKindName;
  config: Record<string, string>;
  secretsCiphertext: string | null;
  testedFingerprint: string | null;
  testedAt: Date | null;
  updatedAt: Date;
  updatedByUserId: string | null;
};

export type IntegrationAudit = {
  actorUserId: string;
  action: 'INTEGRATION_SETTING_UPDATE' | 'INTEGRATION_SETTING_TEST' | 'SENTRY_ISSUE_STATUS_UPDATE';
  reason: string;
  /** Never secret values: secret fields appear as names only. */
  metadata: Record<string, unknown>;
};

export type IntegrationSettingWrite = {
  kind: IntegrationKindName;
  config?: Record<string, string>;
  secretsCiphertext?: string | null;
  testedFingerprint?: string | null;
  testedAt?: Date | null;
  audit: IntegrationAudit;
};

export interface IntegrationSettingsRepository {
  find(kind: IntegrationKindName): Promise<IntegrationSettingRecord | null>;
  /** Upserts the row (missing fields keep their value) and writes one OpsAuditLog row. */
  write(input: IntegrationSettingWrite): Promise<IntegrationSettingRecord>;
  /** One OpsAuditLog row against an existing setting (e.g. an action taken with its credentials). */
  audit(kind: IntegrationKindName, audit: IntegrationAudit): Promise<void>;
}

export class MemoryIntegrationSettingsRepository implements IntegrationSettingsRepository {
  private readonly rows = new Map<IntegrationKindName, IntegrationSettingRecord>();
  readonly audits: Array<IntegrationAudit & { kind: IntegrationKindName }> = [];

  async find(kind: IntegrationKindName): Promise<IntegrationSettingRecord | null> {
    const row = this.rows.get(kind);
    return row ? { ...row, config: { ...row.config } } : null;
  }

  async write(input: IntegrationSettingWrite): Promise<IntegrationSettingRecord> {
    const current = this.rows.get(input.kind);
    const next: IntegrationSettingRecord = {
      id: current?.id ?? randomUUID(),
      kind: input.kind,
      config: input.config ?? current?.config ?? {},
      secretsCiphertext:
        input.secretsCiphertext !== undefined ? input.secretsCiphertext : (current?.secretsCiphertext ?? null),
      testedFingerprint:
        input.testedFingerprint !== undefined ? input.testedFingerprint : (current?.testedFingerprint ?? null),
      testedAt: input.testedAt !== undefined ? input.testedAt : (current?.testedAt ?? null),
      updatedAt: new Date(),
      updatedByUserId: input.audit.actorUserId,
    };
    this.rows.set(input.kind, next);
    this.audits.push({ ...input.audit, kind: input.kind });
    return { ...next, config: { ...next.config } };
  }

  async audit(kind: IntegrationKindName, audit: IntegrationAudit): Promise<void> {
    if (!this.rows.has(kind)) throw new Error(`No ${kind} integration setting`);
    this.audits.push({ ...audit, kind });
  }
}

type Row = {
  id: string;
  kind: IntegrationKindName;
  config: Prisma.JsonValue;
  secretsCiphertext: string | null;
  testedFingerprint: string | null;
  testedAt: Date | null;
  updatedAt: Date;
  updatedByUserId: string | null;
};

export class PrismaIntegrationSettingsRepository implements IntegrationSettingsRepository {
  constructor(private readonly db: PrismaClient) {}

  async find(kind: IntegrationKindName): Promise<IntegrationSettingRecord | null> {
    const row = await this.db.integrationSetting.findUnique({ where: { kind } });
    return row ? mapRow(row) : null;
  }

  async write(input: IntegrationSettingWrite): Promise<IntegrationSettingRecord> {
    return this.db.$transaction(async (tx) => {
      const data = {
        ...(input.config !== undefined ? { config: input.config } : {}),
        ...(input.secretsCiphertext !== undefined ? { secretsCiphertext: input.secretsCiphertext } : {}),
        ...(input.testedFingerprint !== undefined ? { testedFingerprint: input.testedFingerprint } : {}),
        ...(input.testedAt !== undefined ? { testedAt: input.testedAt } : {}),
        updatedByUserId: input.audit.actorUserId,
      };
      const row = await tx.integrationSetting.upsert({
        where: { kind: input.kind },
        create: { id: randomUUID(), kind: input.kind, ...data },
        update: data,
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.audit.actorUserId,
          action: input.audit.action,
          entityType: 'INTEGRATION_SETTING',
          entityId: row.id,
          reason: input.audit.reason,
          metadata: { kind: input.kind, ...input.audit.metadata } as Prisma.InputJsonValue,
        },
      });
      return mapRow(row);
    });
  }

  async audit(kind: IntegrationKindName, audit: IntegrationAudit): Promise<void> {
    const row = await this.db.integrationSetting.findUniqueOrThrow({ where: { kind }, select: { id: true } });
    await this.db.opsAuditLog.create({
      data: {
        id: randomUUID(),
        actorUserId: audit.actorUserId,
        action: audit.action,
        entityType: 'INTEGRATION_SETTING',
        entityId: row.id,
        reason: audit.reason,
        metadata: { kind, ...audit.metadata } as Prisma.InputJsonValue,
      },
    });
  }
}

function mapRow(row: Row): IntegrationSettingRecord {
  const config: Record<string, string> = {};
  if (row.config && typeof row.config === 'object' && !Array.isArray(row.config)) {
    for (const [key, value] of Object.entries(row.config)) {
      if (typeof value === 'string') config[key] = value;
    }
  }
  return {
    id: row.id,
    kind: row.kind,
    config,
    secretsCiphertext: row.secretsCiphertext,
    testedFingerprint: row.testedFingerprint,
    testedAt: row.testedAt,
    updatedAt: row.updatedAt,
    updatedByUserId: row.updatedByUserId,
  };
}
