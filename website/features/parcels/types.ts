export const PARCEL_OUTCOMES = ["PENDING", "DELIVERED", "RETURNING", "RETURNED"] as const;
export type ParcelOutcome = (typeof PARCEL_OUTCOMES)[number];
export const PARCEL_PHOTO_KINDS = ["item", "pickup", "delivery", "return"] as const;
export type ParcelPhotoKind = (typeof PARCEL_PHOTO_KINDS)[number];

export type NestParcelContact = { name: string; phone: string } | null;

export type NestParcelView = {
  sizeClass: string;
  weightKg: number | null;
  note: string | null;
  payer: "SENDER" | "RECIPIENT";
  surchargeVnd: number;
  sender: NestParcelContact;
  recipient: NestParcelContact;
  outcome: ParcelOutcome;
  failReason: string | null;
  failNote: string | null;
  photos: Record<ParcelPhotoKind, boolean>;
  pickedUpAt: string | null;
  deliveredAt: string | null;
  failedAt: string | null;
  returnedAt: string | null;
};

export type NestParcelListRow = NestParcelView & {
  rideId: string;
  createdAt: string;
  ride: {
    status: string;
    vehicleClassCode: string;
    pickupLabel: string | null;
    dropoffLabel: string | null;
    agreedFareVnd: number | null;
    offeredFareVnd: number;
    serviceRegionCode: string | null;
  } | null;
};

export type NestParcelPage = { items: NestParcelListRow[]; page: number; limit: number; total: number };

export type ParcelListItem = {
  id: string;
  createdAt: string;
  sizeClass: string;
  weightLabel: string;
  outcome: ParcelOutcome;
  outcomeLabel: string;
  rideStatus: string;
  route: string;
  fareVnd: number | null;
  sender: string;
  recipient: string;
  vehicleClassCode: string;
};
