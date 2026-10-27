export type RideVehicleClassRow = {
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
