export type RideVehicleClassRow = {
  code: string;
  name: string;
  seats: number;
  enabled: boolean;
  /** DEC-PROD-071: class may carry parcel jobs. */
  parcelEnabled?: boolean;
  baseFareVnd: number;
  perKmVnd: number;
  perMinuteVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  assumedSpeedKmh: number;
  sortOrder: number;
  imageUrl: string | null;
};
