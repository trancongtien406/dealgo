import type { RideStatus } from "@/features/rides/types";

/** Nest: cancel while NEGOTIATING / pre-trip / IN_TRIP (not terminal). */
export function canOpsCancelRide(status: RideStatus): boolean {
  return (
    status === "WAITING" || status === "PICKING_UP" || status === "IN_TRIP"
  );
}

/**
 * Nest TEST_ONLY reassign: ASSIGNED / DRIVER_EN_ROUTE / DRIVER_ARRIVED.
 * Feature map collapses ASSIGNED→WAITING and en-route/arrived→PICKING_UP.
 */
export function canOpsReassignRide(
  status: RideStatus,
  driverLabel: string,
): boolean {
  if (status === "PICKING_UP") {
    return true;
  }
  return (
    status === "WAITING" &&
    driverLabel.trim() !== "—" &&
    driverLabel.trim() !== ""
  );
}
