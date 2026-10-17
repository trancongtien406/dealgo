import type { OpsIconName } from "@/components/ui/ops-icons";
import type { StatusTone } from "@/lib/admin-format";
import type { TxService, TxStatus } from "@/features/transactions/types";

const serviceLabels: Record<TxService, string> = {
  FOOD: "Đồ ăn",
  RIDE: "Chuyến xe",
  DELIVERY: "Giao hàng",
};
const serviceMarks: Record<
  TxService,
  { icon: OpsIconName; className: string }
> = {
  FOOD: { icon: "utensils", className: "bg-food/10 text-food" },
  RIDE: { icon: "car", className: "bg-brand/10 text-brand" },
  DELIVERY: { icon: "package", className: "bg-delivery/10 text-delivery" },
};
const statusLabels: Record<TxStatus, string> = {
  COLLECTED: "Đã thu",
  COD_PENDING: "Chờ xác nhận COD",
  COD_CONFIRMED: "Đã xác nhận COD",
  PROCESSING: "Đang xử lý",
  FAILED: "Thất bại",
};
const statusTones: Record<TxStatus, StatusTone> = {
  COLLECTED: "success",
  COD_PENDING: "food",
  COD_CONFIRMED: "success",
  PROCESSING: "delivery",
  FAILED: "danger",
};
export function txServiceLabel(s: TxService) {
  return serviceLabels[s];
}
export function txServiceMark(s: TxService) {
  return serviceMarks[s];
}
export function txStatusLabel(s: TxStatus) {
  return statusLabels[s];
}
export function txStatusTone(s: TxStatus) {
  return statusTones[s];
}
export const txStatusFilterOptions = [
  { value: "ALL" as const, label: "Tất cả trạng thái" },
  ...(Object.keys(statusLabels) as TxStatus[]).map((value) => ({
    value,
    label: statusLabels[value],
  })),
];
