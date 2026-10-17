import type { FoodOrderStatus } from "@/features/food-orders/types";

/** Nest: cancel until DELIVERED / FAILED / CANCELLED. */
export function canOpsCancelFoodOrder(status: FoodOrderStatus): boolean {
  return status !== "COMPLETED" && status !== "CANCELLED";
}

/**
 * Nest TEST_ONLY reassign: status ASSIGNED only.
 * Feature map: ASSIGNED→DELIVERING (PICKED_UP also DELIVERING — Nest rejects if not ASSIGNED).
 */
export function canOpsReassignFoodOrder(
  status: FoodOrderStatus,
  driver: string | null,
): boolean {
  return status === "DELIVERING" && Boolean(driver?.trim());
}
