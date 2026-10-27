import { HttpException, Inject, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { RIDE_VEHICLE_CLASS_REPOSITORY } from './ride-vehicle-class.constants.js';
import type {
  PatchRideVehicleClassDto,
  UploadRideVehicleClassImageDto,
} from './ride-vehicle-class.dto.js';
import {
  keyFromRideVehicleClassImageUrl,
  resolveVehicleImagePayload,
  rideVehicleClassImageError,
  rideVehicleClassImageKey,
  rideVehicleClassImagePath,
  RIDE_VEHICLE_IMAGE_TYPES,
} from './ride-vehicle-class-image.js';
import type { RideVehicleClassRepository, VehicleClassChanges } from './ride-vehicle-class.repository.js';
import {
  defaultRideVehicleClasses,
  quoteVehicleClassFare,
  type RideVehicleClass,
  type VehicleClassQuote,
} from './ride-vehicle-class.js';

export type RideVehicleClassView = {
  code: string;
  name: string;
  seats: number;
  enabled: boolean;
  baseFareVnd: number;
  perKmVnd: number;
  perMinuteVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  assumedSpeedKmh: number;
  sortOrder: number;
  imageUrl: string | null;
};

export type RideQuoteOptionView = RideVehicleClassView & {
  referenceFareVnd: number;
  durationMin: number;
};

function toView(row: RideVehicleClass): RideVehicleClassView {
  return {
    code: row.code,
    name: row.name,
    seats: row.seats,
    enabled: row.enabled,
    baseFareVnd: row.baseFareVnd,
    perKmVnd: row.perKmVnd,
    perMinuteVnd: row.perMinuteVnd,
    minFareVnd: row.minFareVnd,
    maxFareVnd: row.maxFareVnd,
    assumedSpeedKmh: row.assumedSpeedKmh,
    sortOrder: row.sortOrder,
    imageUrl: row.imageUrl,
  };
}

/** Fields that differ between the stored class and the patched values. */
export function diffVehicleClass(
  current: RideVehicleClass,
  next: Partial<RideVehicleClass>,
): VehicleClassChanges {
  const changes: VehicleClassChanges = {};
  for (const [field, to] of Object.entries(next)) {
    const from = current[field as keyof RideVehicleClass];
    if (to !== undefined && from !== to) {
      changes[field] = { from, to };
    }
  }
  return changes;
}

@Injectable()
export class RideVehicleClassService {
  private pending: Promise<void> | undefined;

  constructor(
    @Inject(RIDE_VEHICLE_CLASS_REPOSITORY)
    private readonly classes: RideVehicleClassRepository,
    private readonly settings: PlatformSettingsService,
    private readonly uploads: DocumentStoreService,
  ) {}

  async listAll(): Promise<RideVehicleClassView[]> {
    const rows = await this.load();
    return rows.map(toView);
  }

  async listEnabled(): Promise<RideVehicleClass[]> {
    const rows = await this.load();
    return rows.filter((row) => row.enabled);
  }

  async findEnabled(code: string): Promise<RideVehicleClass | null> {
    const rows = await this.load();
    const found = rows.find((row) => row.code === code.trim().toUpperCase());
    return found?.enabled ? found : null;
  }

  async findAny(code: string): Promise<RideVehicleClass | null> {
    const rows = await this.load();
    return rows.find((row) => row.code === code.trim().toUpperCase()) ?? null;
  }

  quote(distanceKm: number, vehicle: RideVehicleClass): VehicleClassQuote {
    return quoteVehicleClassFare({ distanceKm, vehicle });
  }

  async update(
    code: string,
    patch: PatchRideVehicleClassDto,
    updatedByUserId: string,
  ): Promise<RideVehicleClassView> {
    const current = await this.findAny(code);
    if (!current) {
      throw new HttpException(
        { message: 'Vehicle class not found', errorCode: 'RIDE_VEHICLE_CLASS_UNKNOWN' },
        404,
      );
    }
    const next = {
      name: patch.name?.trim() || current.name,
      seats: patch.seats ?? current.seats,
      enabled: patch.enabled ?? current.enabled,
      baseFareVnd: patch.baseFareVnd ?? current.baseFareVnd,
      perKmVnd: patch.perKmVnd ?? current.perKmVnd,
      perMinuteVnd: patch.perMinuteVnd ?? current.perMinuteVnd,
      minFareVnd: patch.minFareVnd ?? current.minFareVnd,
      maxFareVnd: patch.maxFareVnd ?? current.maxFareVnd,
      assumedSpeedKmh: patch.assumedSpeedKmh ?? current.assumedSpeedKmh,
    };
    const changed =
      next.name !== current.name ||
      next.seats !== current.seats ||
      next.enabled !== current.enabled ||
      next.baseFareVnd !== current.baseFareVnd ||
      next.perKmVnd !== current.perKmVnd ||
      next.perMinuteVnd !== current.perMinuteVnd ||
      next.minFareVnd !== current.minFareVnd ||
      next.maxFareVnd !== current.maxFareVnd ||
      next.assumedSpeedKmh !== current.assumedSpeedKmh;
    if (!changed) {
      throw new HttpException(
        { message: 'No vehicle class field to update', errorCode: 'VALIDATION_ERROR' },
        400,
      );
    }
    if (next.minFareVnd > next.maxFareVnd) {
      throw new HttpException(
        { message: 'Minimum fare cannot exceed the maximum', errorCode: 'VALIDATION_ERROR' },
        400,
      );
    }
    const changes = diffVehicleClass(current, next);
    const saved = await this.classes.update(current.code, next, updatedByUserId, {
      reason: patch.reason?.trim() || 'Cập nhật hạng xe',
      changes,
    });
    if (!saved) {
      throw new HttpException(
        { message: 'Vehicle class not found', errorCode: 'RIDE_VEHICLE_CLASS_UNKNOWN' },
        404,
      );
    }
    return toView(saved);
  }

  async uploadImage(
    code: string,
    input: UploadRideVehicleClassImageDto,
    updatedByUserId: string,
  ): Promise<RideVehicleClassView> {
    const current = await this.findAny(code);
    if (!current) {
      throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class not found');
    }
    const payload = resolveVehicleImagePayload(input);
    if (!payload) {
      throw rideVehicleClassImageError(400, 'VALIDATION_ERROR', 'contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    if (normalized && !(RIDE_VEHICLE_IMAGE_TYPES as readonly string[]).includes(normalized)) {
      throw rideVehicleClassImageError(
        415,
        'UPLOAD_TYPE_NOT_ALLOWED',
        'Vehicle image must be a JPEG, PNG or WebP image',
      );
    }
    const previous = keyFromRideVehicleClassImageUrl(current.imageUrl);
    const saved = await this.uploads.storeThen(
      `ride-vehicle-classes/${current.code}`,
      [{ label: 'vehicle-class', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!ref || !(RIDE_VEHICLE_IMAGE_TYPES as readonly string[]).includes(ref.contentType)) {
          throw rideVehicleClassImageError(
            415,
            'UPLOAD_TYPE_NOT_ALLOWED',
            'Vehicle image must be a JPEG, PNG or WebP image',
          );
        }
        const imageUrl = rideVehicleClassImagePath(current.code, ref.key);
        const updated = await this.classes.update(current.code, { imageUrl }, updatedByUserId, {
          reason: 'Cập nhật ảnh hạng xe',
          changes: { imageUrl: { from: current.imageUrl, to: imageUrl } },
        });
        if (!updated) {
          throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class not found');
        }
        return updated;
      },
    );
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return toView(saved);
  }

  async clearImage(code: string, updatedByUserId: string): Promise<RideVehicleClassView> {
    const current = await this.findAny(code);
    if (!current) {
      throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class not found');
    }
    const previous = keyFromRideVehicleClassImageUrl(current.imageUrl);
    const updated = await this.classes.update(current.code, { imageUrl: null }, updatedByUserId, {
      reason: 'Xoá ảnh hạng xe',
      changes: { imageUrl: { from: current.imageUrl, to: null } },
    });
    if (!updated) {
      throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class not found');
    }
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return toView(updated);
  }

  async readImage(code: string, file: string): Promise<{ body: Buffer; contentType: string }> {
    const key = rideVehicleClassImageKey(code, file);
    const current = key ? await this.findAny(code) : null;
    if (!key || !current || current.imageUrl !== rideVehicleClassImagePath(current.code, key)) {
      throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_IMAGE_NOT_FOUND', 'Image not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const found = await this.uploads.read({
      key,
      contentType: ext === 'jpg' ? 'image/jpeg' : `image/${ext}`,
    });
    if (!found) {
      throw rideVehicleClassImageError(404, 'RIDE_VEHICLE_CLASS_IMAGE_NOT_FOUND', 'Image not found');
    }
    return found;
  }

  private async load(): Promise<RideVehicleClass[]> {
    await this.ensureDefaults();
    return this.classes.list();
  }

  private async ensureDefaults(): Promise<void> {
    if (this.pending) {
      await this.pending;
      return;
    }
    if ((await this.classes.count()) > 0) {
      return;
    }
    this.pending = this.seed().finally(() => {
      this.pending = undefined;
    });
    await this.pending;
  }

  private async seed(): Promise<void> {
    if ((await this.classes.count()) > 0) {
      return;
    }
    const [minFareVnd, maxFareVnd, perKmVnd] = await Promise.all([
      this.settings.getNumber('RIDE_MIN_FARE_VND'),
      this.settings.getNumber('RIDE_MAX_FARE_VND'),
      this.settings.getNumber('RIDE_REFERENCE_VND_PER_KM'),
    ]);
    await this.classes.insertDefaults(
      defaultRideVehicleClasses({ minFareVnd, maxFareVnd, perKmVnd }),
    );
  }
}
