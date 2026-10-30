export type ZoneTariffOverride = {
  id: string;
  regionCode: string;
  vehicleClassCode: string;
  perKmVnd: number;
  minFareVnd: number;
  version: number;
  updatedByUserId: string | null;
  updatedAt: string;
};

export type ZoneTariffMatrix = {
  regions: Array<{ code: string; name: string; status: "ACTIVE" | "PLANNED" }>;
  classes: Array<{
    code: string;
    name: string;
    defaultPerKmVnd: number;
    defaultMinFareVnd: number;
    maxFareVnd: number;
  }>;
  overrides: ZoneTariffOverride[];
};

/** Client-side check mirroring the server (server stays authoritative). */
export function validateZoneTariff(
  input: { perKmVnd: number; minFareVnd: number },
  maxFareVnd: number,
): string | null {
  if (!Number.isInteger(input.perKmVnd) || input.perKmVnd < 0 || input.perKmVnd > 100_000) {
    return "Giá/km phải là số nguyên từ 0 đến 100.000đ.";
  }
  if (!Number.isInteger(input.minFareVnd) || input.minFareVnd < 0 || input.minFareVnd > maxFareVnd) {
    return `Giá tối thiểu phải từ 0 đến ${new Intl.NumberFormat("vi-VN").format(maxFareVnd)}đ (giá tối đa của loại xe).`;
  }
  return null;
}
