import type { StatusTone } from "@/lib/admin-format";
import {
  PARCEL_OUTCOMES,
  PARCEL_PHOTO_KINDS,
  type NestParcelContact,
  type NestParcelListRow,
  type ParcelListItem,
  type ParcelOutcome,
  type ParcelPhotoKind,
} from "@/features/parcels/types";

export const parcelOutcomeLabel: Record<ParcelOutcome, string> = {
  PENDING: "Đang xử lý",
  DELIVERED: "Đã giao",
  RETURNING: "Đang hoàn hàng",
  RETURNED: "Đã hoàn hàng",
};

export const parcelOutcomeTone: Record<ParcelOutcome, StatusTone> = {
  PENDING: "brand",
  DELIVERED: "success",
  RETURNING: "food",
  RETURNED: "danger",
};

export const parcelPhotoLabel: Record<ParcelPhotoKind, string> = {
  item: "Ảnh hàng (người gửi)",
  pickup: "Ảnh lấy hàng",
  delivery: "Ảnh giao hàng",
  return: "Ảnh hoàn hàng",
};

export const parcelFailReasonLabel: Record<string, string> = {
  RECIPIENT_UNREACHABLE: "Không liên lạc được người nhận",
  RECIPIENT_REFUSED: "Người nhận từ chối",
  ADDRESS_WRONG: "Sai địa chỉ",
  ITEM_DAMAGED: "Hàng hư hỏng",
  OTHER: "Lý do khác",
};

export function isParcelOutcomeFilter(value: string): value is ParcelOutcome {
  return (PARCEL_OUTCOMES as readonly string[]).includes(value);
}

export function isParcelPhotoKind(value: string): value is ParcelPhotoKind {
  return (PARCEL_PHOTO_KINDS as readonly string[]).includes(value);
}

export function contactLabel(contact: NestParcelContact): string {
  return contact ? `${contact.name} · ${contact.phone}` : "—";
}

/** "PENDING" + pickedUpAt reads as "in transit" for ops. */
export function parcelStageLabel(row: { outcome: ParcelOutcome; pickedUpAt: string | null }): string {
  if (row.outcome === "PENDING") return row.pickedUpAt ? "Đang giao" : "Chờ lấy hàng";
  return parcelOutcomeLabel[row.outcome];
}

export function parcelPhotoPath(id: string, kind: ParcelPhotoKind): string {
  return `/api/ops/parcels/${encodeURIComponent(id)}/photos/${kind}`;
}

export function mapNestParcelToListItem(row: NestParcelListRow): ParcelListItem {
  const ride = row.ride;
  return {
    id: row.rideId,
    createdAt: row.createdAt,
    sizeClass: row.sizeClass,
    weightLabel: row.weightKg == null ? "—" : `${row.weightKg} kg`,
    outcome: row.outcome,
    outcomeLabel: parcelStageLabel(row),
    rideStatus: ride?.status ?? "—",
    route: ride ? `${ride.pickupLabel ?? "?"} → ${ride.dropoffLabel ?? "?"}` : "—",
    fareVnd: ride ? (ride.agreedFareVnd ?? ride.offeredFareVnd) : null,
    sender: contactLabel(row.sender),
    recipient: contactLabel(row.recipient),
    vehicleClassCode: ride?.vehicleClassCode ?? "—",
  };
}
