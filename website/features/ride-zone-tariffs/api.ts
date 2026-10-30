import type { ZoneTariffMatrix, ZoneTariffOverride } from "@/features/ride-zone-tariffs/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchZoneTariffs(): Promise<ZoneTariffMatrix> {
  const envelope = await apiFetch<{ success: boolean; data: ZoneTariffMatrix }>(
    apiPaths.opsRideZoneTariffs(),
  );
  return envelope.data;
}

export async function putZoneTariff(input: {
  regionCode: string;
  vehicleClassCode: string;
  perKmVnd: number;
  minFareVnd: number;
  reason?: string;
}): Promise<ZoneTariffOverride> {
  const envelope = await apiFetch<{ success: boolean; data: ZoneTariffOverride }>(
    apiPaths.opsRideZoneTariff(input.regionCode, input.vehicleClassCode),
    {
      method: "PUT",
      body: { perKmVnd: input.perKmVnd, minFareVnd: input.minFareVnd, reason: input.reason },
    },
  );
  return envelope.data;
}

export async function deleteZoneTariff(input: {
  regionCode: string;
  vehicleClassCode: string;
}): Promise<void> {
  await apiFetch(apiPaths.opsRideZoneTariff(input.regionCode, input.vehicleClassCode), {
    method: "DELETE",
  });
}
