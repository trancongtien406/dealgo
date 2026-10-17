import type { StatusTone } from "@/lib/admin-format";
import type { RefundStatus } from "@/features/refunds/types";

const labels: Record<RefundStatus, string> = {
  AWAITING_REVIEW: "Chờ kiểm tra",
  NEEDS_MORE_INFO: "Chờ bổ sung",
  PROCESSING: "Đang xử lý",
  REFUNDED: "Đã hoàn tiền",
  REJECTED: "Từ chối",
  EVIDENCE_REQUESTED: "Yêu cầu chứng cứ",
};
const tones: Record<RefundStatus, StatusTone> = {
  AWAITING_REVIEW: "food",
  NEEDS_MORE_INFO: "food",
  PROCESSING: "delivery",
  REFUNDED: "success",
  REJECTED: "danger",
  EVIDENCE_REQUESTED: "brand",
};

export function refundStatusLabel(status: RefundStatus) {
  return labels[status];
}
export function refundStatusTone(status: RefundStatus) {
  return tones[status];
}

export function resolveRefundOrderRoute(
  service: string,
  orderCode: string,
): {
  href: string | null;
  label: string;
} {
  const s = (service || "").toUpperCase();
  const code = (orderCode || "").toUpperCase();

  if (
    s.includes("RIDE") ||
    s.includes("XE") ||
    code.startsWith("DGX-") ||
    code.startsWith("RD-")
  ) {
    return {
      href: `/rides/${orderCode}`,
      label: `Mở chuyến xe liên quan (${orderCode}) →`,
    };
  }
  if (
    s.includes("FOOD") ||
    s.includes("ĂN") ||
    s.includes("MÓN") ||
    code.startsWith("FA-") ||
    code.startsWith("FO-")
  ) {
    return {
      href: `/food-orders/${orderCode}`,
      label: `Mở đơn đồ ăn liên quan (${orderCode}) →`,
    };
  }
  if (s.includes("DELIVERY") || s.includes("GIAO") || code.startsWith("GH-")) {
    return {
      href: `/deliveries/${orderCode}`,
      label: `Mở đơn giao hàng liên quan (${orderCode}) →`,
    };
  }
  return {
    href: null,
    label: `Đơn liên quan: ${orderCode}`,
  };
}
