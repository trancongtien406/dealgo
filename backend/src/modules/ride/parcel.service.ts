import { randomInt } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { DocumentStoreService, type StoredDocumentRef } from '../../platform/storage/document-store.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  normalizeParcelSizeClasses,
  PARCEL_SIZE_CLASSES_DEFAULT,
  type ParcelSizeClassConfig,
  type ParcelSizeCode,
} from '../../platform/settings/parcel-size-classes.js';
import { RideVehicleClassService } from '../ride-vehicle/ride-vehicle-class.service.js';
import { clampToFareSteps, rideBidCeilingVnd, rideBidFloorVnd } from '../ride-vehicle/ride-vehicle-class.js';
import type { CreateParcelDto, ParcelDeliverDto, ParcelFailDto, ParcelPhotoDto, ParcelPickupDto, QuoteParcelDto } from './parcel.dto.js';
import {
  RIDE_PARCEL_STORE,
  type OpsParcelQuery,
  type ParcelPhotoKind,
  type ParcelRecord,
  type RideParcelStore,
} from './ride-parcel.store.js';
import { rideError } from './ride.error.js';
import { RideService, type RideView } from './ride.service.js';

/** Wrong recipient codes allowed before the driver must call support / fail the job. */
export const PARCEL_RECIPIENT_CODE_MAX_ATTEMPTS = 5;

export type ParcelView = {
  sizeClass: ParcelSizeCode;
  weightKg: number | null;
  note: string | null;
  payer: 'SENDER' | 'RECIPIENT';
  surchargeVnd: number;
  serviceFeeVnd: number;
  returnFeeVnd: number;
  sender: { name: string; phone: string } | null;
  recipient: { name: string; phone: string } | null;
  /** Sender only: give it to the recipient (checked at delivery when required). */
  recipientCode?: string;
  outcome: ParcelRecord['outcome'];
  failReason: string | null;
  failNote: string | null;
  photos: { item: boolean; pickup: boolean; delivery: boolean; return: boolean };
  pickedUpAt: string | null;
  deliveredAt: string | null;
  failedAt: string | null;
  returnedAt: string | null;
};

export type ParcelRideView = RideView & { parcel: ParcelView };

/**
 * DEC-PROD-071 (DRAFT): Giao hàng. A parcel is a Ride (bid band, zone tariff snapshot, offers,
 * Socket.IO rooms, pickup code, cancel rules) plus a package row and photo/code proof.
 */
@Injectable()
export class ParcelService {
  constructor(
    private readonly rides: RideService,
    @Inject(RIDE_PARCEL_STORE) private readonly store: RideParcelStore,
    private readonly documents: DocumentStoreService,
    private readonly settings: PlatformSettingsService,
    private readonly vehicleClasses: RideVehicleClassService,
  ) {}

  async sizeClasses(): Promise<ParcelSizeClassConfig[]> {
    const raw = await this.settings.getJson<unknown>('PARCEL_SIZE_CLASSES').catch(() => PARCEL_SIZE_CLASSES_DEFAULT);
    return normalizeParcelSizeClasses(raw).filter((c) => c.enabled);
  }

  private async sizeConfig(code: ParcelSizeCode, weightKg?: number): Promise<ParcelSizeClassConfig> {
    const size = (await this.sizeClasses()).find((c) => c.code === code);
    if (!size) throw rideError(400, 'PARCEL_SIZE_UNAVAILABLE', 'This package size is not available');
    if (weightKg !== undefined && weightKg > size.maxWeightKg) {
      throw rideError(400, 'PARCEL_TOO_HEAVY', `Max ${size.maxWeightKg} kg for size ${code}`);
    }
    return size;
  }

  /** Classes that may carry this size: admin parcelEnabled ∩ size allow-list (empty = any). */
  private async allowedClassCodes(size: ParcelSizeClassConfig): Promise<Set<string>> {
    const enabled = await this.vehicleClasses.listParcelEnabled();
    return new Set(
      enabled
        .map((v) => v.code)
        .filter((code) => size.vehicleClassCodes.length === 0 || size.vehicleClassCodes.includes(code)),
    );
  }

  /** Admin parcel fees (DEC-PROD-071), read server-side for every quote and booking. */
  private async fees(): Promise<{ serviceFeeVnd: number; returnFeeVnd: number }> {
    const [serviceFeeVnd, returnFeeVnd] = await Promise.all([
      this.settings.getNumber('PARCEL_SERVICE_FEE_VND'),
      this.settings.getNumber('PARCEL_RETURN_FEE_VND'),
    ]);
    return { serviceFeeVnd: Math.max(0, serviceFeeVnd), returnFeeVnd: Math.max(0, returnFeeVnd) };
  }

  async quote(actor: RequestActor, dto: QuoteParcelDto) {
    const size = await this.sizeConfig(dto.sizeClass, dto.weightKg);
    const fees = await this.fees();
    const allowed = await this.allowedClassCodes(size);
    const base = await this.rides.quote(actor, { pickup: dto.pickup, dropoff: dto.dropoff });
    const { floorPercent, ceilingPercent } = await this.rides.currentBand();
    const options = base.options
      .filter((o) => allowed.has(o.code))
      .map((o) => {
        const referenceFareVnd = o.referenceFareVnd + size.surchargeVnd + fees.serviceFeeVnd;
        const minBidVnd = clampToFareSteps(rideBidFloorVnd(referenceFareVnd, floorPercent), o.minFareVnd, o.maxFareVnd);
        const ceiling = rideBidCeilingVnd(referenceFareVnd, ceilingPercent);
        const maxBidVnd = Math.max(
          minBidVnd,
          clampToFareSteps(Number.isFinite(ceiling) ? ceiling : o.maxFareVnd, o.minFareVnd, o.maxFareVnd),
        );
        return { ...o, referenceFareVnd, minBidVnd, maxBidVnd, parcelSurchargeVnd: size.surchargeVnd,
          parcelServiceFeeVnd: fees.serviceFeeVnd,
          parcelReturnFeeVnd: fees.returnFeeVnd,
        };
      });
    if (options.length === 0) {
      throw rideError(400, 'PARCEL_NO_VEHICLE', 'No vehicle class carries this package size right now');
    }
    const primary = options[0]!;
    return {
      ...base,
      referenceFareVnd: primary.referenceFareVnd,
      minFareVnd: primary.minFareVnd,
      maxFareVnd: primary.maxFareVnd,
      minBidVnd: primary.minBidVnd,
      maxBidVnd: primary.maxBidVnd,
      options,
      sizeClass: size,
    };
  }

  async create(actor: RequestActor, idempotencyKey: string, dto: CreateParcelDto): Promise<ParcelRideView> {
    const size = await this.sizeConfig(dto.sizeClass, dto.weightKg);
    const allowed = await this.allowedClassCodes(size);
    if (!allowed.has(dto.vehicleClassCode)) {
      throw rideError(400, 'PARCEL_VEHICLE_NOT_ALLOWED', 'This vehicle class cannot carry this package');
    }
    const fees = await this.fees();
    const payer = dto.payer ?? 'SENDER';
    const paymentMethod = dto.paymentMethod ?? 'CASH';
    if (payer === 'RECIPIENT' && paymentMethod !== 'CASH') {
      throw rideError(400, 'PARCEL_PAYER_METHOD', 'Recipient pays in cash only');
    }
    const itemPhoto = dto.itemPhoto ? await this.storePhoto(`parcels/${idempotencyKey}`, 'item', dto.itemPhoto) : null;
    try {
      const ride = await this.rides.create(
        actor,
        idempotencyKey,
        {
          pickup: dto.pickup,
          dropoff: dto.dropoff,
          offeredFareVnd: dto.offeredFareVnd,
          vehicleClassCode: dto.vehicleClassCode,
          paymentMethod,
        },
        {
          surchargeVnd: size.surchargeVnd,
          record: {
            senderName: dto.sender.name.trim(),
            senderPhone: dto.sender.phone,
            recipientName: dto.recipient.name.trim(),
            recipientPhone: dto.recipient.phone,
            sizeClass: size.code,
            weightKg: dto.weightKg ?? null,
            note: dto.note?.trim() || null,
            payer,
            serviceFeeVnd: fees.serviceFeeVnd,
            returnFeeVnd: fees.returnFeeVnd,
            itemPhoto,
            recipientCode: String(randomInt(0, 10_000)).padStart(4, '0'),
          },
        },
      );
      const parcel = await this.requireParcel(ride.id);
      if (itemPhoto && parcel.itemPhoto?.key !== itemPhoto.key) {
        await this.documents.discard([itemPhoto]); // idempotent replay kept the first photo
      }
      return { ...ride, parcel: this.view(parcel, 'CUSTOMER') };
    } catch (error) {
      if (itemPhoto) await this.documents.discard([itemPhoto]);
      throw error;
    }
  }

  async get(actor: RequestActor, rideId: string): Promise<ParcelRideView> {
    const ride = await this.rides.get(actor, rideId); // 404 unless participant
    const parcel = await this.requireParcel(rideId);
    const role = ride.assignedDriverId === actor.userId ? 'DRIVER' : 'CUSTOMER';
    return { ...ride, parcel: this.view(parcel, role, ride) };
  }

  /** Driver at sender: photo of the package, then the ride goes IN_TRIP (in transit). */
  async pickup(actor: RequestActor, rideId: string, dto: ParcelPickupDto): Promise<ParcelRideView> {
    await this.requireAssignedDriver(actor, rideId, ['DRIVER_ARRIVED', 'DRIVER_EN_ROUTE', 'ASSIGNED']);
    const photo = await this.storePhoto(`parcels/${rideId}`, 'pickup', dto.photo);
    try {
      await this.rides.startTrip(actor, rideId, dto.pickupCode, { parcelProof: true });
    } catch (error) {
      await this.documents.discard([photo]);
      throw error;
    }
    await this.store.update(rideId, ['PENDING'], { pickupPhoto: photo, pickedUpAt: new Date() });
    return this.get(actor, rideId);
  }

  async deliver(actor: RequestActor, rideId: string, dto: ParcelDeliverDto): Promise<ParcelRideView> {
    await this.requireAssignedDriver(actor, rideId, ['IN_TRIP']);
    const parcel = await this.requireParcel(rideId);
    if (parcel.outcome !== 'PENDING') {
      throw rideError(409, 'PARCEL_STATE', 'This package is being returned');
    }
    if (await this.settings.getBoolean('PARCEL_RECIPIENT_CODE_REQUIRED')) {
      if (!(await this.store.reserveCodeAttempt(rideId, PARCEL_RECIPIENT_CODE_MAX_ATTEMPTS))) {
        throw rideError(429, 'PARCEL_CODE_LOCKED', 'Too many wrong codes; contact support or mark failed');
      }
      if (!dto.recipientCode || dto.recipientCode !== parcel.recipientCode) {
        throw rideError(400, 'PARCEL_CODE_INVALID', 'Recipient code does not match');
      }
    }
    const photo = await this.storePhoto(`parcels/${rideId}`, 'delivery', dto.photo);
    try {
      await this.rides.complete(actor, rideId, { parcelProof: true });
    } catch (error) {
      await this.documents.discard([photo]);
      throw error;
    }
    await this.store.update(rideId, ['PENDING'], { deliveryPhoto: photo, deliveredAt: new Date(), outcome: 'DELIVERED' });
    return this.get(actor, rideId);
  }

  /** Delivery failed: the driver brings the package back to the sender (ride stays IN_TRIP). */
  async fail(actor: RequestActor, rideId: string, dto: ParcelFailDto): Promise<ParcelRideView> {
    await this.requireAssignedDriver(actor, rideId, ['IN_TRIP']);
    const updated = await this.store.update(
      rideId,
      ['PENDING'],
      { outcome: 'RETURNING', failReason: dto.reason, failNote: dto.note?.trim() || null, failedAt: new Date() },
      { status: 'IN_TRIP', suffix: 'parcel:RETURNING', payload: { parcelOutcome: 'RETURNING', reason: dto.reason } },
    );
    if (!updated) throw rideError(409, 'PARCEL_STATE', 'Package is not in transit');
    return this.get(actor, rideId);
  }

  /**
   * Package handed back to the sender (photo); closes the ride. The booking-time
   * PARCEL_RETURN_FEE_VND snapshot is booked as a PARCEL_RETURN customer fee in the same
   * transaction as the completion (paid to the driver, collected on the sender's next cash ride).
   */
  async returned(actor: RequestActor, rideId: string, dto: { photo: ParcelPhotoDto }): Promise<ParcelRideView> {
    await this.requireAssignedDriver(actor, rideId, ['IN_TRIP']);
    const parcel = await this.requireParcel(rideId);
    if (parcel.outcome !== 'RETURNING') throw rideError(409, 'PARCEL_STATE', 'Mark the delivery failed first');
    const photo = await this.storePhoto(`parcels/${rideId}`, 'return', dto.photo);
    try {
      await this.rides.complete(actor, rideId, { parcelProof: true, returnFeeVnd: parcel.returnFeeVnd });
    } catch (error) {
      await this.documents.discard([photo]);
      throw error;
    }
    await this.store.update(rideId, ['RETURNING'], { returnPhoto: photo, returnedAt: new Date(), outcome: 'RETURNED' });
    return this.get(actor, rideId);
  }

  async photo(actor: RequestActor | null, rideId: string, kind: ParcelPhotoKind) {
    if (actor) await this.rides.get(actor, rideId); // participants only (ops pass null)
    const parcel = await this.requireParcel(rideId);
    const ref = this.photoRef(parcel, kind);
    const found = ref ? await this.documents.read(ref) : null;
    if (!found) throw rideError(404, 'PARCEL_PHOTO_NOT_FOUND', 'Photo not found');
    return found;
  }

  async listForOps(query: { page?: number; limit?: number; outcome?: OpsParcelQuery['outcome']; q?: string }) {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const result = await this.store.listForOps({ page, limit, outcome: query.outcome, q: query.q?.trim() || undefined });
    return { items: result.items.map((row) => ({ ...this.view(row, 'OPS'), rideId: row.rideId, createdAt: row.createdAt.toISOString(), ride: row.ride })), page, limit, total: result.total };
  }

  async getForOps(rideId: string) {
    const ride = await this.rides.getForOps(rideId);
    return { ...ride, serviceKind: 'PARCEL' as const, parcel: this.view(await this.requireParcel(rideId), 'OPS') };
  }

  private photoRef(parcel: ParcelRecord, kind: ParcelPhotoKind): StoredDocumentRef | null {
    switch (kind) {
      case 'item':
        return parcel.itemPhoto;
      case 'pickup':
        return parcel.pickupPhoto;
      case 'delivery':
        return parcel.deliveryPhoto;
      case 'return':
        return parcel.returnPhoto;
    }
  }

  private async storePhoto(prefix: string, label: string, photo: ParcelPhotoDto): Promise<StoredDocumentRef> {
    const [ref] = await this.documents.storeAll(prefix, [
      { label, contentType: photo.contentType, contentBase64: photo.contentBase64 },
    ]);
    return ref!;
  }

  private async requireParcel(rideId: string): Promise<ParcelRecord> {
    const parcel = await this.store.find(rideId);
    if (!parcel) throw rideError(404, 'PARCEL_NOT_FOUND', 'Parcel not found');
    return parcel;
  }

  private async requireAssignedDriver(actor: RequestActor, rideId: string, statuses: RideView['status'][]) {
    const ride = await this.rides.get(actor, rideId);
    if (ride.assignedDriverId !== actor.userId) throw rideError(403, 'RIDE_NOT_DRIVER', 'Not your job');
    if (!statuses.includes(ride.status)) throw rideError(409, 'RIDE_INVALID_STATE', 'Not allowed in this state');
    await this.requireParcel(rideId);
    return ride;
  }

  /** Contacts: driver sees them once assigned; recipient code only for the sender. */
  view(parcel: ParcelRecord, role: 'CUSTOMER' | 'DRIVER' | 'OPS', ride?: RideView): ParcelView {
    const showContacts = role !== 'DRIVER' || (ride && ride.status !== 'NEGOTIATING');
    return {
      sizeClass: parcel.sizeClass,
      weightKg: parcel.weightKg,
      note: parcel.note,
      payer: parcel.payer,
      surchargeVnd: parcel.surchargeVnd,
      serviceFeeVnd: parcel.serviceFeeVnd,
      returnFeeVnd: parcel.returnFeeVnd,
      sender: showContacts ? { name: parcel.senderName, phone: parcel.senderPhone } : null,
      recipient: showContacts ? { name: parcel.recipientName, phone: parcel.recipientPhone } : null,
      ...(role === 'CUSTOMER' && parcel.recipientCode ? { recipientCode: parcel.recipientCode } : {}),
      outcome: parcel.outcome,
      failReason: parcel.failReason,
      failNote: parcel.failNote,
      photos: {
        item: Boolean(parcel.itemPhoto),
        pickup: Boolean(parcel.pickupPhoto),
        delivery: Boolean(parcel.deliveryPhoto),
        return: Boolean(parcel.returnPhoto),
      },
      pickedUpAt: parcel.pickedUpAt?.toISOString() ?? null,
      deliveredAt: parcel.deliveredAt?.toISOString() ?? null,
      failedAt: parcel.failedAt?.toISOString() ?? null,
      returnedAt: parcel.returnedAt?.toISOString() ?? null,
    };
  }
}
