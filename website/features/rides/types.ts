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
  /** Nest catalog code when present (DG-DEC-VEH-001). */
  vehicleClassCode: string | null;
  price: number;
  /** DEC-PROD-024: voucher discount (0 when none) and the cash the driver collects. */
  discountVnd: number;
  voucherCode: string | null;
  cashDueVnd: number;
  status: RideStatus;
  /** DEC-PROD-035: "Khách hàng huỷ" … (null unless cancelled). */
  cancelledBy: string | null;
  /** Vietnamese reason label (driver cancel reason, timeout, no-show). */
  cancelReason?: string | null;
  time: string;
  /** Real coordinates for the route sketch (null when the payload lacks them). */
  pickupPoint: GeoPoint | null;
  dropoffPoint: GeoPoint | null;
};

export type GeoPoint = { lat: number; lng: number };

export type RideListFilters = {
  status: RideStatus | "ALL";
  q: string;
  page: number;
  limit: number;
};
