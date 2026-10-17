/** Nest RideView subset used by Admin BFF (envelope.data). */
export type NestRideStatus =
  | "NEGOTIATING"
  | "ASSIGNED"
  | "DRIVER_EN_ROUTE"
  | "DRIVER_ARRIVED"
  | "IN_TRIP"
  | "COMPLETED"
  | "CANCELLED"
  | "EXPIRED";

export type NestRideOffer = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: string;
  status: string;
  expiresAt: string;
};

export type NestRideView = {
  id: string;
  status: NestRideStatus;
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  offeredFareVnd: number;
  referenceFareVnd: number;
  agreedFareVnd: number | null;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: string;
  /** Present on Nest RideView; used when assignedDriverId is null. */
  offers?: NestRideOffer[];
};

export type NestRidePage = {
  items: NestRideView[];
  page: number;
  limit: number;
  total: number;
};
