import { randomUUID } from 'node:crypto';
import {
  HttpException,
  Injectable,
  Logger,
  type OnModuleDestroy,
  type OnModuleInit,
} from '@nestjs/common';
import {
  SERVICE_REGIONS,
  setServiceRegionCatalog,
  type ServiceRegion,
  type ServiceRegionBBox,
  type ServiceRegionStatus,
} from './service-regions.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { AuditLogsService } from '../../platform/audit/index.js';

/** Zone as exposed to Admin (adds persistence metadata to the catalog shape). */
export type ServiceRegionView = ServiceRegion & {
  id: string;
  sortOrder: number;
  updatedAt: string | null;
};

export type CreateServiceRegionInput = {
  code: string;
  label: string;
  centerLat: number;
  centerLng: number;
  bbox: ServiceRegionBBox;
  status?: ServiceRegionStatus;
};

export type PatchServiceRegionInput = {
  label?: string;
  centerLat?: number;
  centerLng?: number;
  bbox?: ServiceRegionBBox;
  status?: ServiceRegionStatus;
};

const REFRESH_INTERVAL_MS = 30_000;

/** Vietnam sanity bounds (catalog is a Vietnam MVP; guards typos like swapped lat/lng). */
const VN_LAT: readonly [number, number] = [8.0, 23.6];
const VN_LNG: readonly [number, number] = [102.0, 110.0];
/** A single zone bbox larger than this would swallow neighbouring cities. */
const MAX_BBOX_SPAN_DEG = 3;

const CODE_PATTERN = /^[A-Z][A-Z0-9]{1,7}$/;

export class ServiceRegionError extends HttpException {
  constructor(
    status: number,
    readonly errorCode: string,
    message: string,
  ) {
    super({ message, errorCode }, status);
  }
}

function regionError(status: number, errorCode: string, message: string): ServiceRegionError {
  return new ServiceRegionError(status, errorCode, message);
}

export function normalizeRegionCodeInput(raw: string): string {
  return raw.trim().toUpperCase();
}

/** Throws a 400 {@link ServiceRegionError} when the zone geometry/label is not acceptable. */
export function validateServiceRegionShape(region: {
  code: string;
  label: string;
  centerLat: number;
  centerLng: number;
  bbox: ServiceRegionBBox;
}): void {
  if (!CODE_PATTERN.test(region.code)) {
    throw regionError(
      400,
      'SERVICE_REGION_INVALID',
      'Mã vùng phải gồm 2–8 ký tự A–Z/0–9 và bắt đầu bằng chữ cái',
    );
  }
  const label = region.label.trim();
  if (label.length < 2 || label.length > 80) {
    throw regionError(400, 'SERVICE_REGION_INVALID', 'Tên vùng phải dài 2–80 ký tự');
  }
  const { bbox, centerLat, centerLng } = region;
  const numbers = [
    centerLat,
    centerLng,
    bbox.minLat,
    bbox.maxLat,
    bbox.minLng,
    bbox.maxLng,
  ];
  if (!numbers.every((n) => Number.isFinite(n))) {
    throw regionError(400, 'SERVICE_REGION_INVALID', 'Toạ độ phải là số hợp lệ');
  }
  const inLat = (v: number) => v >= VN_LAT[0] && v <= VN_LAT[1];
  const inLng = (v: number) => v >= VN_LNG[0] && v <= VN_LNG[1];
  if (
    ![centerLat, bbox.minLat, bbox.maxLat].every(inLat) ||
    ![centerLng, bbox.minLng, bbox.maxLng].every(inLng)
  ) {
    throw regionError(
      400,
      'SERVICE_REGION_INVALID',
      'Toạ độ nằm ngoài lãnh thổ Việt Nam (vĩ độ 8–23.6, kinh độ 102–110)',
    );
  }
  if (bbox.minLat >= bbox.maxLat || bbox.minLng >= bbox.maxLng) {
    throw regionError(400, 'SERVICE_REGION_INVALID', 'Khung vùng: min phải nhỏ hơn max');
  }
  if (
    bbox.maxLat - bbox.minLat > MAX_BBOX_SPAN_DEG ||
    bbox.maxLng - bbox.minLng > MAX_BBOX_SPAN_DEG
  ) {
    throw regionError(
      400,
      'SERVICE_REGION_INVALID',
      `Khung vùng quá lớn (tối đa ${MAX_BBOX_SPAN_DEG}° mỗi chiều)`,
    );
  }
  if (
    centerLat < bbox.minLat ||
    centerLat > bbox.maxLat ||
    centerLng < bbox.minLng ||
    centerLng > bbox.maxLng
  ) {
    throw regionError(400, 'SERVICE_REGION_INVALID', 'Tâm vùng phải nằm trong khung vùng');
  }
}

function normalizeLabelKey(label: string): string {
  return label.trim().replace(/\s+/g, ' ').toLowerCase();
}

type RegionRow = {
  id: string;
  code: string;
  label: string;
  centerLat: number;
  centerLng: number;
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
  status: ServiceRegionStatus;
  sortOrder: number;
  updatedAt: Date;
};

function rowToView(row: RegionRow): ServiceRegionView {
  return {
    id: row.id,
    code: row.code,
    label: row.label,
    centerLat: row.centerLat,
    centerLng: row.centerLng,
    bbox: {
      minLat: row.minLat,
      maxLat: row.maxLat,
      minLng: row.minLng,
      maxLng: row.maxLng,
    },
    status: row.status,
    sortOrder: row.sortOrder,
    updatedAt: row.updatedAt.toISOString(),
  };
}

function defaultViews(): ServiceRegionView[] {
  return SERVICE_REGIONS.map((region, index) => ({
    ...region,
    id: randomUUID(),
    sortOrder: index,
    updatedAt: null,
  }));
}

/**
 * Admin-managed zones. Persists to `service_regions` when a DB is configured
 * (in-memory fallback for tests/dev) and keeps the synchronous catalog registry
 * used by ride/food code in sync.
 */
@Injectable()
export class ServiceRegionsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ServiceRegionsService.name);
  private views: ServiceRegionView[] = defaultViews();
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogsService,
  ) {}

  async onModuleInit(): Promise<void> {
    this.publish();
    await this.refresh();
    this.timer = setInterval(() => {
      void this.refresh();
    }, REFRESH_INTERVAL_MS);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /** Reload zones from DB (no-op in memory mode) and republish the catalog. */
  async refresh(): Promise<void> {
    const db = this.prisma.db();
    if (!db) {
      return;
    }
    try {
      const rows = await db.serviceRegion.findMany({
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
      });
      if (rows.length === 0) {
        // Table exists but is empty: keep bootstrap defaults rather than serving no zones.
        return;
      }
      this.views = rows.map((row) => rowToView(row as RegionRow));
      this.publish();
    } catch (error) {
      this.logger.warn(`Service region refresh failed: ${String(error)}`);
    }
  }

  async list(status?: ServiceRegionStatus): Promise<ServiceRegionView[]> {
    await this.refresh();
    return status ? this.views.filter((v) => v.status === status) : [...this.views];
  }

  async create(
    input: CreateServiceRegionInput,
    reason: string,
    actorUserId: string,
  ): Promise<ServiceRegionView> {
    const code = normalizeRegionCodeInput(input.code);
    const label = input.label.trim().replace(/\s+/g, ' ');
    const status: ServiceRegionStatus = input.status ?? 'PLANNED';
    validateServiceRegionShape({ ...input, code, label });

    await this.refresh();
    this.assertUnique(code, label, null);
    const sortOrder = this.views.reduce((max, v) => Math.max(max, v.sortOrder), -1) + 1;
    const { bbox } = input;

    const db = this.prisma.db();
    let created: ServiceRegionView;
    if (db) {
      try {
        const row = await db.$transaction(async (tx) => {
          const inserted = await tx.serviceRegion.create({
            data: {
              id: randomUUID(),
              code,
              label,
              centerLat: input.centerLat,
              centerLng: input.centerLng,
              minLat: bbox.minLat,
              maxLat: bbox.maxLat,
              minLng: bbox.minLng,
              maxLng: bbox.maxLng,
              status,
              sortOrder,
            },
          });
          await tx.opsAuditLog.create({
            data: {
              id: randomUUID(),
              actorUserId,
              action: 'SERVICE_REGION_UPDATE',
              entityType: 'SERVICE_REGION',
              entityId: inserted.id,
              reason,
              metadata: { op: 'CREATE', code, label, status },
            },
          });
          return inserted;
        });
        created = rowToView(row as RegionRow);
      } catch (error) {
        if (isUniqueViolation(error)) {
          throw regionError(409, 'SERVICE_REGION_CODE_TAKEN', `Mã vùng ${code} đã tồn tại`);
        }
        throw error;
      }
    } else {
      created = {
        id: randomUUID(),
        code,
        label,
        centerLat: input.centerLat,
        centerLng: input.centerLng,
        bbox: { ...bbox },
        status,
        sortOrder,
        updatedAt: new Date().toISOString(),
      };
      this.audit.record({
        actor: actorUserId,
        actorId: actorUserId,
        action: 'Tạo khu vực',
        target: `${code} (${label})`,
        entityType: 'SERVICE_REGION',
        entityId: created.id,
        reason,
        result: 'SUCCESS',
        metadata: { op: 'CREATE', code, label, status },
      });
    }

    this.views = [...this.views, created];
    this.publish();
    return created;
  }

  async update(
    codeRaw: string,
    patch: PatchServiceRegionInput,
    reason: string,
    actorUserId: string,
  ): Promise<ServiceRegionView> {
    const code = normalizeRegionCodeInput(codeRaw);
    await this.refresh();
    const current = this.views.find((v) => v.code === code);
    if (!current) {
      throw regionError(404, 'SERVICE_REGION_NOT_FOUND', `Không tìm thấy vùng ${code}`);
    }

    const label = patch.label !== undefined
      ? patch.label.trim().replace(/\s+/g, ' ')
      : current.label;
    const merged: ServiceRegionView = {
      ...current,
      label,
      centerLat: patch.centerLat ?? current.centerLat,
      centerLng: patch.centerLng ?? current.centerLng,
      bbox: patch.bbox ? { ...patch.bbox } : current.bbox,
      status: patch.status ?? current.status,
    };

    validateServiceRegionShape(merged);
    this.assertUnique(code, label, current.id);
    if (
      current.status === 'ACTIVE' &&
      merged.status !== 'ACTIVE' &&
      this.views.filter((v) => v.status === 'ACTIVE').length <= 1
    ) {
      throw regionError(
        400,
        'SERVICE_REGION_LAST_ACTIVE',
        'Không thể tắt vùng ACTIVE cuối cùng — hãy bật vùng khác trước',
      );
    }

    const changes = {
      label: merged.label !== current.label ? { from: current.label, to: merged.label } : undefined,
      status: merged.status !== current.status ? { from: current.status, to: merged.status } : undefined,
      geometry:
        merged.centerLat !== current.centerLat ||
        merged.centerLng !== current.centerLng ||
        JSON.stringify(merged.bbox) !== JSON.stringify(current.bbox),
    };

    const db = this.prisma.db();
    let updated: ServiceRegionView;
    if (db) {
      const row = await db.$transaction(async (tx) => {
        const saved = await tx.serviceRegion.update({
          where: { id: current.id },
          data: {
            label: merged.label,
            centerLat: merged.centerLat,
            centerLng: merged.centerLng,
            minLat: merged.bbox.minLat,
            maxLat: merged.bbox.maxLat,
            minLng: merged.bbox.minLng,
            maxLng: merged.bbox.maxLng,
            status: merged.status,
          },
        });
        await tx.opsAuditLog.create({
          data: {
            id: randomUUID(),
            actorUserId,
            action: 'SERVICE_REGION_UPDATE',
            entityType: 'SERVICE_REGION',
            entityId: saved.id,
            reason,
            metadata: { op: 'UPDATE', code, ...changes },
          },
        });
        return saved;
      });
      updated = rowToView(row as RegionRow);
    } else {
      updated = { ...merged, updatedAt: new Date().toISOString() };
      this.audit.record({
        actor: actorUserId,
        actorId: actorUserId,
        action: 'Cập nhật khu vực',
        target: `${code} (${merged.label})`,
        entityType: 'SERVICE_REGION',
        entityId: updated.id,
        reason,
        result: 'SUCCESS',
        metadata: { op: 'UPDATE', code, ...changes },
      });
    }

    this.views = this.views.map((v) => (v.id === updated.id ? updated : v));
    this.publish();
    return updated;
  }

  private assertUnique(code: string, label: string, selfId: string | null): void {
    const labelKey = normalizeLabelKey(label);
    for (const v of this.views) {
      if (v.id === selfId) {
        continue;
      }
      if (v.code === code) {
        throw regionError(409, 'SERVICE_REGION_CODE_TAKEN', `Mã vùng ${code} đã tồn tại`);
      }
      if (normalizeLabelKey(v.label) === labelKey) {
        throw regionError(
          409,
          'SERVICE_REGION_LABEL_TAKEN',
          `Tên vùng "${label}" đã được dùng bởi ${v.code}`,
        );
      }
    }
  }

  private publish(): void {
    setServiceRegionCatalog(
      this.views.map(({ code, label, centerLat, centerLng, bbox, status }) => ({
        code,
        label,
        centerLat,
        centerLng,
        bbox,
        status,
      })),
    );
  }
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}
