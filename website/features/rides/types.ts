export const RIDE_STATUSES = [
  "WAITING",
  "PICKING_UP",
  "IN_TRIP",
  "COMPLETED",
  "CANCELLED",
] as const;

export type RideStatus = (typeof RIDE_STATUSES)[number];

export type RideListItem = {
  code: string;
  customer: string;
  phone: string;
  driver: string;
  plate: string;
  pickup: string;
  pickupArea: string;
  dropoff: string;
  dropoffArea: string;
  seats: string;
  price: number;
  status: RideStatus;
  time: string;
};

export type RideListFilters = {
  status: RideStatus | "ALL";
  q: string;
  page: number;
  limit: number;
};
