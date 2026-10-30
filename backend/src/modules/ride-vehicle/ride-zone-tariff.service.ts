import { HttpException, Inject, Injectable } from '@nestjs/common';
import {
  getServiceRegion,
  inferRegionCodeFromCoords,
  listServiceRegions,
} from '../service-area/service-regions.js';
import { RIDE_ZONE_TARIFF_REPOSITORY } from './ride-vehicle-class.constants.js';
import type { RideVehicleClass } from './ride-vehicle-class.js';
import { RideVehicleClassService } from './ride-vehicle-class.service.js';
import type {
  RidePricingSnapshot,
  RideZoneTariff,
  RideZoneTariffRepository,
} from './ride-zone-tariff.repository.js';

/** Bounds for an override; same as the class editor (whole VND, non-negative). */
export const ZONE_TARIFF_MAX_PER_KM_VND = 100_000;

/** Which tariff priced a quote; returned to the client and locked onto the ride. */
export type ResolvedTariff = {
  source: 'ZONE' | 'DEFAULT';
  regionCode: string | null;
  zoneTariffId: string | null;
  version: number;
  perKmVnd: number;
  minFareVnd: number;
};

/**
 * Applies a zone override (perKm + minFare only) to a class. Pure, so the quote path and
 * tests share it. Min fare is clamped to the class max so a quote never inverts.
 */
export function applyZoneTariff(
  vehicle: RideVehicleClass,
  regionCode: string | null,
  override: RideZoneTariff | undefined,
): { vehicle: RideVehicleClass; tariff: ResolvedTariff } {
  if (!override) {
    return {
      vehicle,
      tariff: {
        source: 'DEFAULT',
        regionCode,
        zoneTariffId: null,
        version: 0,
        perKmVnd: vehicle.perKmVnd,
        minFareVnd: vehicle.minFareVnd,
      },
    };
  }
  const minFareVnd = Math.min(override.minFareVnd, vehicle.maxFareVnd);
  return {
    vehicle: { ...vehicle, perKmVnd: override.perKmVnd, minFareVnd },
    tariff: {
      source: 'ZONE',
      regionCode,
      zoneTariffId: override.id,
      version: override.version,
      perKmVnd: override.perKmVnd,
      minFareVnd,
    },
  };
}

@Injectable()
export class RideZoneTariffService {
  constructor(
    @Inject(RIDE_ZONE_TARIFF_REPOSITORY)
    private readonly repo: RideZoneTariffRepository,
    private readonly classes: RideVehicleClassService,
  ) {}

  /** Admin view: every catalog region x class, with the override if one exists. */
  async listMatrix() {
    const [rows, classes] = await Promise.all([this.repo.list(), this.classes.listAll()]);
    return {
      regions: listServiceRegions().map((r) => ({ code: r.code, name: r.label, status: r.status })),
      classes: classes.map((c) => ({
        code: c.code,
        name: c.name,
        defaultPerKmVnd: c.perKmVnd,
        defaultMinFareVnd: c.minFareVnd,
        maxFareVnd: c.maxFareVnd,
      })),
      overrides: rows,
    };
  }

  async upsert(
    regionCodeRaw: string,
    classCodeRaw: string,
    input: { perKmVnd: number; minFareVnd: number; reason?: string },
    actorUserId: string,
  ): Promise<RideZoneTariff> {
    const { regionCode, vehicle } = await this.validateTarget(regionCodeRaw, classCodeRaw);
    const perKmVnd = input.perKmVnd;
    const minFareVnd = input.minFareVnd;
    if (!Number.isInteger(perKmVnd) || perKmVnd < 0 || perKmVnd > ZONE_TARIFF_MAX_PER_KM_VND) {
      throw validation(`perKmVnd must be an integer 0..${ZONE_TARIFF_MAX_PER_KM_VND}`);
    }
    if (!Number.isInteger(minFareVnd) || minFareVnd < 0 || minFareVnd > vehicle.maxFareVnd) {
      throw validation(`minFareVnd must be an integer 0..${vehicle.maxFareVnd} (class max fare)`);
    }
    const current = (await this.repo.list()).find(
      (r) => r.regionCode === regionCode && r.vehicleClassCode === vehicle.code,
    );
    if (current && current.perKmVnd === perKmVnd && current.minFareVnd === minFareVnd) {
      throw validation('No zone tariff field to update');
    }
    return this.repo.upsert({ regionCode, vehicleClassCode: vehicle.code, perKmVnd, minFareVnd }, actorUserId, {
      action: 'RIDE_ZONE_TARIFF_UPSERT',
      reason: input.reason?.trim() || 'Cập nhật giá theo khu vực',
      changes: {
        perKmVnd: { from: current?.perKmVnd ?? null, to: perKmVnd },
        minFareVnd: { from: current?.minFareVnd ?? null, to: minFareVnd },
      },
    });
  }

  async remove(regionCodeRaw: string, classCodeRaw: string, actorUserId: string, reason?: string) {
    const { regionCode, vehicle } = await this.validateTarget(regionCodeRaw, classCodeRaw);
    const current = (await this.repo.list()).find(
      (r) => r.regionCode === regionCode && r.vehicleClassCode === vehicle.code,
    );
    if (!current) {
      throw new HttpException({ message: 'Zone tariff not found', errorCode: 'RIDE_ZONE_TARIFF_UNKNOWN' }, 404);
    }
    await this.repo.remove(regionCode, vehicle.code, actorUserId, {
      action: 'RIDE_ZONE_TARIFF_DELETE',
      reason: reason?.trim() || 'Xoá giá theo khu vực (về mặc định)',
      changes: {
        perKmVnd: { from: current.perKmVnd, to: null },
        minFareVnd: { from: current.minFareVnd, to: null },
      },
    });
    return { deleted: true };
  }

  /** Server-side: zone from the pickup point (any catalog region), then override or global default. */
  async resolve(
    vehicle: RideVehicleClass,
    pickup: { lat: number; lng: number },
  ): Promise<{ vehicle: RideVehicleClass; tariff: ResolvedTariff }> {
    const regionCode = inferRegionCodeFromCoords(pickup.lat, pickup.lng);
    const override = regionCode
      ? (await this.repo.list()).find((r) => r.regionCode === regionCode && r.vehicleClassCode === vehicle.code)
      : undefined;
    return applyZoneTariff(vehicle, regionCode, override);
  }

  /** Re-applies a locked snapshot so a later admin edit never reprices an existing ride. */
  applySnapshot(vehicle: RideVehicleClass, snapshot: RidePricingSnapshot): RideVehicleClass {
    return { ...vehicle, perKmVnd: snapshot.perKmVnd, minFareVnd: snapshot.minFareVnd };
  }

  saveSnapshot(snapshot: RidePricingSnapshot): Promise<void> {
    return this.repo.saveSnapshot(snapshot);
  }

  findSnapshot(rideId: string): Promise<RidePricingSnapshot | null> {
    return this.repo.findSnapshot(rideId);
  }

  private async validateTarget(regionCodeRaw: string, classCodeRaw: string) {
    const regionCode = regionCodeRaw.trim().toUpperCase();
    if (!getServiceRegion(regionCode)) {
      throw new HttpException({ message: 'Unknown service region', errorCode: 'SERVICE_REGION_UNKNOWN' }, 404);
    }
    const vehicle = await this.classes.findAny(classCodeRaw);
    if (!vehicle) {
      throw new HttpException({ message: 'Vehicle class not found', errorCode: 'RIDE_VEHICLE_CLASS_UNKNOWN' }, 404);
    }
    return { regionCode, vehicle };
  }
}

function validation(message: string) {
  return new HttpException({ message, errorCode: 'VALIDATION_ERROR' }, 400);
}
