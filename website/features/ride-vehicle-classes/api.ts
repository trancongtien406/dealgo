import type { RideVehicleClassRow } from "@/features/ride-vehicle-classes/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchRideVehicleClasses(): Promise<RideVehicleClassRow[]> {
  const envelope = await apiFetch<{
    success: boolean;
    data: RideVehicleClassRow[];
  }>(apiPaths.opsRideVehicleClasses());
  return envelope.data;
}

export function vehicleClassImageSrc(imageUrl: string | null | undefined): string | null {
  if (!imageUrl) {
    return null;
  }
  const prefix = "/v1/public/ride-vehicle-classes/";
  if (!imageUrl.startsWith(prefix)) {
    return null;
  }
  return `/api/public/ride-vehicle-classes/${imageUrl.slice(prefix.length)}`;
}

export async function uploadRideVehicleClassImage(
  code: string,
  dataUrl: string,
): Promise<RideVehicleClassRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: RideVehicleClassRow;
  }>(apiPaths.opsRideVehicleClassImage(code), {
    method: "POST",
    body: { dataUrl },
  });
  return envelope.data;
}

export async function clearRideVehicleClassImage(
  code: string,
): Promise<RideVehicleClassRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: RideVehicleClassRow;
  }>(apiPaths.opsRideVehicleClassImage(code), {
    method: "DELETE",
  });
  return envelope.data;
}

export async function patchRideVehicleClass(
  code: string,
  input: Partial<Omit<RideVehicleClassRow, "code" | "sortOrder" | "imageUrl">>,
): Promise<RideVehicleClassRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: RideVehicleClassRow;
  }>(apiPaths.opsRideVehicleClass(code), {
    method: "PATCH",
    body: input,
  });
  return envelope.data;
}
