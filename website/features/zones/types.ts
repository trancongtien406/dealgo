export const PRICE_STATUSES = ["ACTIVE", "DRAFT"] as const;
export type PriceStatus = (typeof PRICE_STATUSES)[number];

export type ZoneService = "RIDE" | "FOOD" | "PLATFORM";

export type ZoneBBox = {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
};

export type ZoneItem = {
  id?: string;
  code: string;
  name: string;
  label: string;
  status: "ACTIVE" | "PLANNED" | string;
  centerLat?: number;
  centerLng?: number;
  bbox?: ZoneBBox;
  sortOrder?: number;
  updatedAt?: string | null;
  demandRideCount: number;
  demandFoodCount: number;
  demandCount: number;
};

export type CreateZoneInput = {
  code: string;
  label: string;
  centerLat: number;
  centerLng: number;
  bbox: ZoneBBox;
  status?: "ACTIVE" | "PLANNED";
  reason: string;
};

export type PatchZoneInput = {
  label?: string;
  centerLat?: number;
  centerLng?: number;
  bbox?: ZoneBBox;
  status?: "ACTIVE" | "PLANNED";
  reason: string;
};

/** Platform pricing / radius setting exposed as an ops “rule”. */
export type ZoneRule = {
  code: string;
  name: string;
  service: ZoneService | string;
  zone: string;
  status: PriceStatus;
  value: string;
  unit: string;
  displayValue: string;
  updatedAt: string | null;
};
