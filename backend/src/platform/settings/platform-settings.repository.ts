import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type { PlatformSettingKey, PlatformSettingValueTypeName } from './platform-settings.catalog.js';

export type PlatformSettingRecord = {
  id: string;
  key: PlatformSettingKey;
  value: string;
  valueType: PlatformSettingValueTypeName;
  updatedAt: Date;
  updatedByUserId: string | null;
};

export type PlatformSettingUpsertInput = {
  key: PlatformSettingKey;
  value: string;
  valueType: PlatformSettingValueTypeName;
  updatedByUserId: string | null;
  reason: string | null;
  previousValue: string | null;
};

export interface PlatformSettingsRepository {
  list(): Promise<PlatformSettingRecord[]>;
  findByKey(key: PlatformSettingKey): Promise<PlatformSettingRecord | null>;
  upsert(input: PlatformSettingUpsertInput): Promise<PlatformSettingRecord>;
  ensureDefaults(
    defaults: ReadonlyArray<{
      key: PlatformSettingKey;
      value: string;
      valueType: PlatformSettingValueTypeName;
    }>,
  ): Promise<void>;
}

export class MemoryPlatformSettingsRepository implements PlatformSettingsRepository {
  private readonly byKey = new Map<PlatformSettingKey, PlatformSettingRecord>();
  readonly audits: Array<{
    action: 'SETTINGS_UPDATE';
    entityId: string;
    actorUserId: string;
    reason: string;
    metadata: Record<string, unknown>;
  }> = [];

  async list(): Promise<PlatformSettingRecord[]> {
    return [...this.byKey.values()].sort((a, b) => a.key.localeCompare(b.key));
  }

  async findByKey(key: PlatformSettingKey): Promise<PlatformSettingRecord | null> {
    return this.byKey.get(key) ?? null;
  }

  async upsert(input: PlatformSettingUpsertInput): Promise<PlatformSettingRecord> {
    const existing = this.byKey.get(input.key);
    const record: PlatformSettingRecord = {
      id: existing?.id ?? randomUUID(),
      key: input.key,
      value: input.value,
      valueType: input.valueType,
      updatedAt: new Date(),
      updatedByUserId: input.updatedByUserId,
    };
    this.byKey.set(input.key, record);
    if (input.updatedByUserId && input.reason) {
      this.audits.push({
        action: 'SETTINGS_UPDATE',
        entityId: record.id,
        actorUserId: input.updatedByUserId,
        reason: input.reason,
        metadata: {
          key: input.key,
          value: input.value,
          previousValue: input.previousValue,
          valueType: input.valueType,
        },
      });
    }
    return record;
  }

  async ensureDefaults(
    defaults: ReadonlyArray<{
      key: PlatformSettingKey;
      value: string;
      valueType: PlatformSettingValueTypeName;
    }>,
  ): Promise<void> {
    for (const row of defaults) {
      if (this.byKey.has(row.key)) {
        continue;
      }
      this.byKey.set(row.key, {
        id: randomUUID(),
        key: row.key,
        value: row.value,
        valueType: row.valueType,
        updatedAt: new Date(),
        updatedByUserId: null,
      });
    }
  }
}

export class PrismaPlatformSettingsRepository implements PlatformSettingsRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(): Promise<PlatformSettingRecord[]> {
    const rows = await this.db.platformSetting.findMany({ orderBy: { key: 'asc' } });
    return rows.map(mapRow);
  }

  async findByKey(key: PlatformSettingKey): Promise<PlatformSettingRecord | null> {
    const row = await this.db.platformSetting.findUnique({ where: { key } });
    return row ? mapRow(row) : null;
  }

  async upsert(input: PlatformSettingUpsertInput): Promise<PlatformSettingRecord> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.platformSetting.upsert({
        where: { key: input.key },
        create: {
          id: randomUUID(),
          key: input.key,
          value: input.value,
          valueType: input.valueType,
          updatedByUserId: input.updatedByUserId,
        },
        update: {
          value: input.value,
          valueType: input.valueType,
          updatedByUserId: input.updatedByUserId,
        },
      });

      if (input.updatedByUserId && input.reason) {
        await tx.opsAuditLog.create({
          data: {
            id: randomUUID(),
            actorUserId: input.updatedByUserId,
            action: 'SETTINGS_UPDATE',
            entityType: 'PLATFORM_SETTING',
            entityId: updated.id,
            reason: input.reason,
            metadata: {
              key: input.key,
              value: input.value,
              previousValue: input.previousValue,
              valueType: input.valueType,
            },
          },
        });
      }

      return mapRow(updated);
    });
  }

  async ensureDefaults(
    defaults: ReadonlyArray<{
      key: PlatformSettingKey;
      value: string;
      valueType: PlatformSettingValueTypeName;
    }>,
  ): Promise<void> {
    for (const row of defaults) {
      await this.db.platformSetting.upsert({
        where: { key: row.key },
        create: {
          id: randomUUID(),
          key: row.key,
          value: row.value,
          valueType: row.valueType,
        },
        update: {},
      });
    }
  }
}

function mapRow(row: {
  id: string;
  key: string;
  value: string;
  valueType: string;
  updatedAt: Date;
  updatedByUserId: string | null;
}): PlatformSettingRecord {
  return {
    id: row.id,
    key: row.key as PlatformSettingKey,
    value: row.value,
    valueType: row.valueType as PlatformSettingValueTypeName,
    updatedAt: row.updatedAt,
    updatedByUserId: row.updatedByUserId,
  };
}
