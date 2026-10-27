import { Injectable, Logger } from '@nestjs/common';
import {
  activeServiceRegionsLabel,
  type ServiceRegionBBox,
  type ServiceRegionStatus,
} from './service-regions.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import { OPEN_FOOD_STATUSES } from '../food-order/food.constants.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import type { CreateOpsZoneDto, PatchOpsZoneDto } from './service-zones.dto.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import type { PlatformSettingKey } from '../../platform/settings/platform-settings.catalog.js';
import {
  ServiceRegionsService,
  type ServiceRegionView,
} from './service-regions.service.js';

export type OpsZoneItem = {
  id: string;
  code: string;
  name: string;
  label: string;
  status: ServiceRegionStatus;
  centerLat: number;
  centerLng: number;
  bbox: ServiceRegionBBox;
  sortOrder: number;
  updatedAt: string | null;
  demandRideCount: number;
  demandFoodCount: number;
  demandCount: number;
};

export type OpsPricingRuleItem = {
  code: string;
  name: string;
  service: 'RIDE' | 'FOOD' | 'PLATFORM';
  zone: string;
  status: 'ACTIVE';
  value: string;
  unit: string;
  updatedAt: string | null;
};

const PRICING_RULE_SPECS: ReadonlyArray<{
  key: PlatformSettingKey;
  code: string;
  name: string;
  service: OpsPricingRuleItem['service'];
  unit: string;
}> = [
  {
    key: 'RIDE_MIN_FARE_VND',
    code: 'RIDE_MIN_FARE_VND',
    name: 'Giá sàn chuyến xe',
    service: 'RIDE',
    unit: 'VND',
  },
  {
    key: 'RIDE_MAX_FARE_VND',
    code: 'RIDE_MAX_FARE_VND',
    name: 'Giá trần chuyến xe',
    service: 'RIDE',
    unit: 'VND',
  },
  {
    key: 'RIDE_REFERENCE_VND_PER_KM',
    code: 'RIDE_REFERENCE_VND_PER_KM',
    name: 'Giá tham chiếu theo km',
    service: 'RIDE',
    unit: 'VND/km',
  },
  {
    key: 'DRIVER_SEARCH_RADIUS_KM',
    code: 'DRIVER_SEARCH_RADIUS_KM',
    name: 'Bán kính tìm tài xế',
    service: 'PLATFORM',
    unit: 'km',
  },
  {
    key: 'FOOD_MIN_DELIVERY_VND',
    code: 'FOOD_MIN_DELIVERY_VND',
    name: 'Phí giao tối thiểu',
    service: 'FOOD',
    unit: 'VND',
  },
  {
    key: 'FOOD_MAX_DELIVERY_VND',
    code: 'FOOD_MAX_DELIVERY_VND',
    name: 'Phí giao tối đa',
    service: 'FOOD',
    unit: 'VND',
  },
];

/** Settings that only seed `ride_vehicle_classes` on first boot (Not live prices). */
const SEED_ONLY_RIDE_PRICE_KEYS: ReadonlySet<PlatformSettingKey> = new Set([
  'RIDE_MIN_FARE_VND',
  'RIDE_MAX_FARE_VND',
  'RIDE_REFERENCE_VND_PER_KM',
]);

const OPEN_RIDE_STATUSES = [
  'NEGOTIATING',
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
] as const;

const ZONES_CACHE_TTL_MS = 30_000;

type DemandByCode = Map<string, { rides: number; food: number }>;

@Injectable()
export class OpsZonesService {
  private readonly logger = new Logger(OpsZonesService.name);
  private zonesCache: { atMs: number; value: OpsZoneItem[] } | null = null;
  private zonesInFlight: Promise<OpsZoneItem[]> | null = null;

  constructor(
    private readonly platformSettings: PlatformSettingsService,
    private readonly prisma: PrismaService,
    private readonly regions: ServiceRegionsService,
  ) {}

  /** Default ACTIVE (pilot view); `ALL` / `PLANNED` back the zone management table. */
  async listZones(
    options: { status?: ServiceRegionStatus | 'ALL' } = {},
    now = new Date(),
  ): Promise<{ items: OpsZoneItem[] }> {
    const all = await this.loadAllCached(now);
    const status = options.status ?? 'ACTIVE';
    return {
      items: status === 'ALL' ? all : all.filter((z) => z.status === status),
    };
  }

  async createZone(
    body: CreateOpsZoneDto,
    actorUserId: string,
  ): Promise<OpsZoneItem> {
    const created = await this.regions.create(
      {
        code: body.code,
        label: body.label,
        centerLat: body.centerLat,
        centerLng: body.centerLng,
        bbox: body.bbox,
        status: body.status,
      },
      body.reason,
      actorUserId,
    );
    this.invalidateZones();
    return toZoneItem(created, { rides: 0, food: 0 });
  }

  async patchZone(
    code: string,
    body: PatchOpsZoneDto,
    actorUserId: string,
  ): Promise<OpsZoneItem> {
    const { reason, ...patch } = body;
    const updated = await this.regions.update(code, patch, reason, actorUserId);
    this.invalidateZones();
    const all = await this.loadAllCached(new Date());
    return (
      all.find((z) => z.code === updated.code) ??
      toZoneItem(updated, { rides: 0, food: 0 })
    );
  }

  private invalidateZones(): void {
    this.zonesCache = null;
  }

  private async loadAllCached(now: Date): Promise<OpsZoneItem[]> {
    const hit = this.zonesCache;
    if (hit && now.getTime() - hit.atMs < ZONES_CACHE_TTL_MS) {
      return hit.value;
    }
    if (this.zonesInFlight) {
      return this.zonesInFlight;
    }

    this.zonesInFlight = this.loadZones()
      .then((value) => {
        this.zonesCache = { atMs: Date.now(), value };
        return value;
      })
      .finally(() => {
        this.zonesInFlight = null;
      });

    return this.zonesInFlight;
  }

  async listRules(options: {
    page?: number;
    limit?: number;
    q?: string;
  }): Promise<PageResult<OpsPricingRuleItem>> {
    const safePage = normalizePage(options.page);
    const safeLimit = normalizeLimit(options.limit);
    const settings = await this.platformSettings.list();
    const byKey = new Map(settings.map((s) => [s.key, s]));
    const zoneLabel = activeServiceRegionsLabel();

    // Ride prices live on the vehicle classes (the RIDE_* settings only seed the classes
    // on first boot), so the live per-class values replace those rows when the DB is up.
    const classRules = await this.vehicleClassRules(zoneLabel);
    const specs = classRules
      ? PRICING_RULE_SPECS.filter((spec) => !SEED_ONLY_RIDE_PRICE_KEYS.has(spec.key))
      : PRICING_RULE_SPECS;
    let rules: OpsPricingRuleItem[] = specs.map((spec) => {
      const row = byKey.get(spec.key);
      return {
        code: spec.code,
        name: spec.name,
        service: spec.service,
        zone: zoneLabel,
        status: 'ACTIVE' as const,
        value: row?.value ?? '',
        unit: spec.unit,
        updatedAt: row?.updatedAt ?? null,
      };
    });

    if (classRules) {
      rules = [...classRules, ...rules];
    }

    if (options.q?.trim()) {
      const q = options.q.trim().toLowerCase();
      rules = rules.filter(
        (r) =>
          r.code.toLowerCase().includes(q) ||
          r.name.toLowerCase().includes(q) ||
          r.service.toLowerCase().includes(q) ||
          r.zone.toLowerCase().includes(q) ||
          r.value.toLowerCase().includes(q),
      );
    }

    const total = rules.length;
    const start = (safePage - 1) * safeLimit;
    return {
      items: rules.slice(start, start + safeLimit),
      page: safePage,
      limit: safeLimit,
      total,
    };
  }

  /** Live Ride price rows per enabled vehicle class; null when there is no DB (memory mode). */
  private async vehicleClassRules(zone: string): Promise<OpsPricingRuleItem[] | null> {
    const db = this.prisma.db();
    if (!db) {
      return null;
    }
    let classes: Array<{
      code: string;
      name: string;
      baseFareVnd: number;
      perKmVnd: number;
      minFareVnd: number;
      maxFareVnd: number;
      updatedAt: Date;
    }>;
    try {
      classes = await db.rideVehicleClass.findMany({
        where: { enabled: true },
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
        select: {
          code: true,
          name: true,
          baseFareVnd: true,
          perKmVnd: true,
          minFareVnd: true,
          maxFareVnd: true,
          updatedAt: true,
        },
      });
    } catch (error) {
      this.logger.warn(`vehicle class pricing rows unavailable: ${String(error)}`);
      return null;
    }
    if (classes.length === 0) {
      return null;
    }
    return classes.flatMap((vehicle) => {
      const row = (suffix: string, name: string, value: number, unit: string) => ({
        code: `RIDE_${vehicle.code}_${suffix}`,
        name: `${name} · ${vehicle.name}`,
        service: 'RIDE' as const,
        zone,
        status: 'ACTIVE' as const,
        value: String(value),
        unit,
        updatedAt: vehicle.updatedAt.toISOString(),
      });
      return [
        row('MIN_FARE_VND', 'Giá sàn chuyến xe', vehicle.minFareVnd, 'VND'),
        row('MAX_FARE_VND', 'Giá trần chuyến xe', vehicle.maxFareVnd, 'VND'),
        row('BASE_FARE_VND', 'Giá mở cửa', vehicle.baseFareVnd, 'VND'),
        row('PER_KM_VND', 'Giá tham chiếu theo km', vehicle.perKmVnd, 'VND/km'),
      ];
    });
  }

  private async loadZones(): Promise<OpsZoneItem[]> {
    const regions = await this.regions.list();
    const demand = await this.batchDemandByRegionCode(regions);
    return regions.map((region) =>
      toZoneItem(region, demand.get(region.code) ?? { rides: 0, food: 0 }),
    );
  }

  /** One grouped COUNT per entity instead of N per-zone label scans. */
  private async batchDemandByRegionCode(
    regions: readonly ServiceRegionView[],
  ): Promise<DemandByCode> {
    const result: DemandByCode = new Map(
      regions.map((r) => [r.code, { rides: 0, food: 0 }]),
    );
    const db = this.prisma.db();
    if (!db) {
      return result;
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const codes = regions.map((r) => r.code);

    try {
      const [rideRows, foodRows] = await Promise.all([
        db.ride.groupBy({
          by: ['serviceRegionCode'],
          where: {
            status: { in: [...OPEN_RIDE_STATUSES] },
            updatedAt: { gte: since },
            serviceRegionCode: { in: codes },
          },
          _count: { _all: true },
        }),
        db.foodOrder.groupBy({
          by: ['serviceRegionCode'],
          where: {
            status: { in: [...OPEN_FOOD_STATUSES] },
            updatedAt: { gte: since },
            serviceRegionCode: { in: codes },
          },
          _count: { _all: true },
        }),
      ]);

      for (const row of rideRows) {
        const code = row.serviceRegionCode;
        if (!code) continue;
        const entry = result.get(code);
        if (entry) {
          entry.rides = row._count._all;
        }
      }
      for (const row of foodRows) {
        const code = row.serviceRegionCode;
        if (!code) continue;
        const entry = result.get(code);
        if (entry) {
          entry.food = row._count._all;
        }
      }
    } catch (error) {
      this.logger.warn(`Zone demand batch count failed: ${String(error)}`);
    }

    return result;
  }
}

function toZoneItem(
  region: ServiceRegionView,
  counts: { rides: number; food: number },
): OpsZoneItem {
  return {
    id: region.id,
    code: region.code,
    name: region.label,
    label: region.label,
    status: region.status,
    centerLat: region.centerLat,
    centerLng: region.centerLng,
    bbox: region.bbox,
    sortOrder: region.sortOrder,
    updatedAt: region.updatedAt,
    demandRideCount: counts.rides,
    demandFoodCount: counts.food,
    demandCount: counts.rides + counts.food,
  };
}

export {
  OpsZonesService as ServiceZonesService,
  OpsZonesService as ZoneService,
};

