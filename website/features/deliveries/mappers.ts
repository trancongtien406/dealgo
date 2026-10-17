import type { StatusTone } from "@/lib/admin-format";
import type { DeliveryStatus } from "@/features/deliveries/types";

const labels: Record<DeliveryStatus, string> = {
  DELIVERING: "Đang giao",
  WAITING_DRIVER: "Chờ tài xế",
  PICKED_UP: "Đã lấy hàng",
  COMPLETED: "Hoàn thành",
  FAILED: "Giao thất bại",
};
const tones: Record<DeliveryStatus, StatusTone> = {
  DELIVERING: "delivery",
  WAITING_DRIVER: "brand",
  PICKED_UP: "food",
  COMPLETED: "success",
  FAILED: "danger",
};

export function deliveryStatusLabel(status: DeliveryStatus) {
  return labels[status];
}
export function deliveryStatusTone(status: DeliveryStatus) {
  return tones[status];
}
