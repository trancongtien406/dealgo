import { cancelActorLabel } from "@/lib/cancel-actor";
import { vnd, type StatusTone } from "@/lib/admin-format";
import type {
  NestFoodLineOption,
  NestFoodOrderStatus,
  NestFoodOrderView,
} from "@/features/food-orders/nest-types";
import type {
  FoodOrderListItem,
  FoodOrderStatus,
} from "@/features/food-orders/types";
import { serviceRegionLabel } from "@/lib/service-region-labels";
import { geoPoint, personLabel } from "@/features/rides/mappers";

const nestFoodStatusMap: Record<NestFoodOrderStatus, FoodOrderStatus> = {
  PLACED: "AWAITING_CONFIRMATION",
  PREPARING: "PREPARING",
  READY: "PREPARING",
  ASSIGNED: "DELIVERING",
  PICKED_UP: "DELIVERING",
  DELIVERED: "COMPLETED",
  FAILED: "CANCELLED",
  CANCELLED: "CANCELLED",
};

export function nestFoodOrderStatusToFeature(
  status: NestFoodOrderStatus,
): FoodOrderStatus {
  return nestFoodStatusMap[status];
}

/** Chosen options as one readable line (DEC-PROD-033). */
export function formatLineOptions(
  options: NestFoodLineOption[] | undefined,
): string {
  if (!Array.isArray(options)) return "";
  return options
    .filter((option) => option && typeof option.name === "string")
    .map((option) => {
      const group = option.groupName?.trim();
      const delta =
        option.priceDeltaVnd > 0
          ? ` (+${vnd(option.priceDeltaVnd)})`
          : "";
      return `${group ? `${group}: ` : ""}${option.name}${delta}`;
    })
    .join(" · ");
}

export function mapNestFoodOrderToListItem(
  order: NestFoodOrderView,
): FoodOrderListItem {
  const lines = (order.lines ?? []).map((line) => ({
    name: line.name,
    quantity: line.quantity,
    unitPriceVnd: line.unitPriceVnd,
    options: formatLineOptions(line.options),
  }));
  const items =
    lines.length > 0
      ? lines.map((line) => `${line.name} x${line.quantity}`).join(", ")
      : "—";
  const storeName = order.storeName?.trim();
  return {
    code: order.id,
    customer: personLabel(order.customerProfile, "Khách", order.customerId),
    customerPhone: order.customerProfile?.phoneMasked ?? null,
    store: storeName || actorLabel("CH", order.storeId),
    regionLabel:
      serviceRegionLabel(order.serviceRegionCode) ??
      order.serviceRegionCode?.trim() ??
      "—",
    items,
    lines,
    total: order.totalVnd,
    payment: "COD",
    driver: order.assignedDriverId
      ? personLabel(order.driverProfile, "TX", order.assignedDriverId)
      : null,
    status: nestFoodOrderStatusToFeature(order.status),
    time: order.dropoff.label.trim() || "—",
    cancelReason: foodCancelReasonLabel(order.cancelReason),
    cancelledBy: cancelActorLabel(order.cancelledBy),
    pickupPoint: geoPoint(order.pickup),
    dropoffPoint: geoPoint(order.dropoff),
  };
}

const FOOD_REJECT_LABELS: Record<string, string> = {
  OUT_OF_STOCK: "Hết món",
  STORE_BUSY: "Quán đang quá tải",
  STORE_CLOSING: "Quán sắp đóng cửa",
  ITEM_PRICE_CHANGED: "Giá món đã thay đổi",
  OTHER: "Lý do khác",
};

export function foodCancelReasonLabel(
  reason: NestFoodOrderView["cancelReason"],
): string | null {
  if (!reason) return null;
  const label = FOOD_REJECT_LABELS[reason.code] ?? FOOD_REJECT_LABELS.OTHER;
  const note = reason.note?.trim();
  return note ? `${label} — ${note}` : label;
}

function actorLabel(prefix: string, id: string): string {
  return `${prefix} · ${shortId(id)}`;
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

const labels: Record<FoodOrderStatus, string> = {
  AWAITING_CONFIRMATION: "Chờ xác nhận",
  PREPARING: "Đang chuẩn bị",
  DELIVERING: "Đang giao",
  COMPLETED: "Hoàn thành",
  CANCELLED: "Đã hủy",
};

const tones: Record<FoodOrderStatus, StatusTone> = {
  AWAITING_CONFIRMATION: "brand",
  PREPARING: "food",
  DELIVERING: "delivery",
  COMPLETED: "success",
  CANCELLED: "danger",
};

export function foodOrderStatusLabel(status: FoodOrderStatus): string {
  return labels[status];
}

export function foodOrderStatusTone(status: FoodOrderStatus): StatusTone {
  return tones[status];
}

export const foodOrderStatusTabs = [
  { value: "ALL" as const, label: "Tất cả", count: 892 },
  {
    value: "AWAITING_CONFIRMATION" as const,
    label: labels.AWAITING_CONFIRMATION,
    count: 76,
  },
  { value: "PREPARING" as const, label: labels.PREPARING, count: 194 },
  { value: "DELIVERING" as const, label: labels.DELIVERING, count: 142 },
  { value: "COMPLETED" as const, label: labels.COMPLETED, count: 450 },
  { value: "CANCELLED" as const, label: labels.CANCELLED, count: 30 },
];

export const foodOrderStatusFilterOptions = foodOrderStatusTabs.map(
  ({ value, label }) => ({ value, label }),
);
