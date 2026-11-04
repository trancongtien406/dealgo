import { formatOpsDateTime } from "@/lib/ops-time";
import type { StatusTone } from "@/lib/admin-format";
import type {
  DriverTopUp,
  DriverTopUpStatus,
} from "@/features/driver-credit/types";

const statusLabels: Record<DriverTopUpStatus, string> = {
  PENDING: "Chờ quét QR",
  PAID: "Đã ghi có",
  EXPIRED: "Hết hạn",
  CANCELLED: "Đã huỷ",
  REFUND_PENDING: "Chờ hoàn",
  REFUNDED: "Đã hoàn",
  FAILED: "Thất bại",
};

const statusTones: Record<DriverTopUpStatus, StatusTone> = {
  PENDING: "food",
  PAID: "success",
  EXPIRED: "danger",
  CANCELLED: "danger",
  REFUND_PENDING: "delivery",
  REFUNDED: "delivery",
  FAILED: "danger",
};

const providerLabels: Record<string, string> = {
  PAYOS: "PayOS",
  VNPAY: "VNPay",
  MOMO: "MoMo",
  ZALOPAY: "ZaloPay",
  MANUAL: "Chuyển khoản tay",
};

export const topUpStatusOptions = (
  Object.keys(statusLabels) as DriverTopUpStatus[]
).map((status) => ({ value: status, label: statusLabels[status] }));

export function topUpStatusLabel(status: DriverTopUpStatus): string {
  return statusLabels[status] ?? status;
}

export function topUpStatusTone(status: DriverTopUpStatus): StatusTone {
  return statusTones[status] ?? "brand";
}

export function providerLabel(provider: string): string {
  return providerLabels[provider] ?? provider;
}

/** Order code is what the driver sees on the bank transfer memo. */
export function topUpMemo(topUp: DriverTopUp): string {
  return `NAP${topUp.orderCode}`;
}

export function driverDisplayName(topUp: DriverTopUp): string {
  return topUp.driverName?.trim() || topUp.driverId.slice(0, 8);
}

export function canReconcile(topUp: DriverTopUp): boolean {
  return topUp.status === "PENDING";
}

/** Only settled credit that has not been consumed or refunded can go back to the driver. */
export function canRefund(topUp: DriverTopUp): boolean {
  return topUp.status === "PAID" && topUp.remainingVnd > 0;
}

export function topUpUpdatedAt(topUp: DriverTopUp): string {
  return formatOpsDateTime(topUp.refundedAt ?? topUp.paidAt ?? topUp.createdAt);
}

export function consumedRatio(topUp: DriverTopUp): number {
  if (topUp.amountVnd <= 0) {
    return 0;
  }
  return Math.min(1, Math.max(0, topUp.consumedVnd / topUp.amountVnd));
}
