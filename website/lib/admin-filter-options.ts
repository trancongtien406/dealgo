"use client";

import { useMemo } from "react";
import type { SearchSelectOption } from "@/components/ui/search-select";
import { useCatalogCategoriesQuery } from "@/features/catalog/hooks";
import { useZonesQuery } from "@/features/zones/hooks";

/** Shared Admin list toolbar filter options. */

export const regionFilterOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả khu vực" },
];

export const rideServiceTypeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả loại xe" },
  { value: "BIKE", label: "Xe máy" },
  { value: "CAR4", label: "Ô tô 4 chỗ" },
  { value: "CAR7", label: "Ô tô 7 chỗ" },
];

export const paymentMethodOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Mọi phương thức" },
  { value: "CASH", label: "Tiền mặt" },
  { value: "WALLET", label: "Ví DealGo" },
  { value: "CARD", label: "Thẻ / ngân hàng" },
  { value: "MOMO", label: "MoMo" },
  { value: "VNPAY", label: "VNPay" },
];

export const serviceScopeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả dịch vụ" },
  { value: "RIDE", label: "Chuyến xe" },
  { value: "FOOD", label: "Đồ ăn" },
  { value: "DELIVERY", label: "Giao hàng" },
];

export const driverActivityOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "ONLINE", label: "Đang online" },
  { value: "BUSY", label: "Đang nhận chuyến" },
  { value: "OFFLINE", label: "Offline" },
  { value: "SUSPENDED", label: "Tạm khóa" },
];

export const kycStatusUiOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "PENDING", label: "Chờ duyệt" },
  { value: "APPROVED", label: "Đã duyệt" },
  { value: "REJECTED", label: "Từ chối" },
  { value: "NEED_MORE", label: "Cần bổ sung" },
];

export const storeStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "OPEN", label: "Đang mở" },
  { value: "BUSY", label: "Bếp đang bận" },
  { value: "PAUSED", label: "Tạm ngưng nhận đơn" },
  { value: "CLOSED", label: "Không còn món bán" },
  { value: "SUSPENDED", label: "Tạm khóa" },
];

export const storeKybOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "PENDING", label: "Chờ duyệt" },
  { value: "APPROVED", label: "Đã duyệt" },
  { value: "REJECTED", label: "Từ chối" },
];

/** Stores without map coordinates cannot take delivery orders. */
export const storeLocationOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "MISSING", label: "Chưa ghim vị trí" },
];

export const deliveryCargoOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả loại hàng" },
  { value: "DOC", label: "Tài liệu" },
  { value: "FOOD", label: "Thực phẩm" },
  { value: "PARCEL", label: "Bưu kiện" },
  { value: "FRAGILE", label: "Dễ vỡ" },
];

export const deliveryModeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Giao thường / nhanh" },
  { value: "STANDARD", label: "Giao thường" },
  { value: "EXPRESS", label: "Giao nhanh" },
];

export const deliveryStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "PENDING", label: "Chờ lấy hàng" },
  { value: "PICKED_UP", label: "Đã lấy hàng" },
  { value: "DELIVERING", label: "Đang giao" },
  { value: "DONE", label: "Hoàn thành" },
  { value: "CANCELLED", label: "Đã hủy" },
];

export const negotiationStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "OPEN", label: "Đang mở (thương lượng)" },
  { value: "LOCKED", label: "Đã gán tài xế" },
  { value: "ACCEPTED", label: "Đã hoàn thành" },
  { value: "EXPIRED", label: "Hết hạn / hủy" },
];

export const disputeTypeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả loại" },
  { value: "PAYMENT", label: "Thanh toán" },
  { value: "QUALITY", label: "Chất lượng" },
  { value: "CANCEL", label: "Hủy chuyến/đơn" },
  { value: "OTHER", label: "Khác" },
];

export const disputePartyOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "CUSTOMER", label: "Khách hàng" },
  { value: "DRIVER", label: "Tài xế" },
  { value: "MERCHANT", label: "Cửa hàng" },
];

export const disputeStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "OPEN", label: "Mở" },
  { value: "IN_REVIEW", label: "Đang xử lý" },
  { value: "RESOLVED", label: "Đã giải quyết" },
  { value: "REJECTED", label: "Từ chối" },
];

export const disputePriorityOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "P1", label: "P1 — Khẩn" },
  { value: "P2", label: "P2 — Cao" },
  { value: "P3", label: "P3 — Thường" },
];

export const refundStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "AWAITING_REVIEW", label: "Chờ kiểm tra" },
  { value: "NEEDS_MORE_INFO", label: "Cần bổ sung" },
  { value: "EVIDENCE_REQUESTED", label: "Chờ bằng chứng" },
  { value: "PROCESSING", label: "Đang xử lý" },
  { value: "REFUNDED", label: "Đã hoàn" },
  { value: "REJECTED", label: "Từ chối" },
];

export const zoneServiceOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "RIDE", label: "Chuyến xe" },
  { value: "FOOD", label: "Đồ ăn" },
  { value: "DELIVERY", label: "Giao hàng" },
];

export const zoneStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "ACTIVE", label: "Đang áp dụng" },
  { value: "DRAFT", label: "Nháp" },
  { value: "DISABLED", label: "Tắt" },
];

export const staffRoleOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "ADMIN", label: "Quản trị" },
  { value: "OPS", label: "Vận hành" },
  { value: "SUPPORT", label: "CSKH" },
  { value: "FINANCE", label: "Tài chính" },
];

export const staffStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "ACTIVE", label: "Đang hoạt động" },
  { value: "INVITED", label: "Đã mời / chờ" },
  { value: "SUSPENDED", label: "Tạm khóa" },
];

export const staffScopeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "NATIONAL", label: "Toàn quốc" },
  { value: "CITY", label: "Theo thành phố" },
  { value: "ZONE", label: "Theo vùng" },
];

export const notificationChannelOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "PUSH", label: "Push" },
  { value: "SMS", label: "SMS" },
  { value: "EMAIL", label: "Email" },
  { value: "IN_APP", label: "In-app" },
];

export const notificationAudienceOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "CUSTOMER", label: "Khách hàng" },
  { value: "DRIVER", label: "Tài xế" },
  { value: "MERCHANT", label: "Cửa hàng" },
  { value: "STAFF", label: "Nhân viên" },
];

export const catalogStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "ACTIVE", label: "Đang bán" },
  { value: "HIDDEN", label: "Ẩn" },
  { value: "DRAFT", label: "Nháp" },
];

export const catalogSortOptions: SearchSelectOption[] = [
  { value: "ORDER", label: "Thứ tự" },
  { value: "NAME", label: "Tên A–Z" },
  { value: "UPDATED", label: "Cập nhật gần nhất" },
];

export const catalogModerationStoreOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả cửa hàng" },
];

export const catalogCategoryOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả danh mục" },
];

export const catalogModerationStatusOptions: SearchSelectOption[] = [
  { value: "PENDING", label: "Chờ duyệt" },
  { value: "APPROVED", label: "Đã duyệt" },
  { value: "REJECTED", label: "Từ chối" },
  { value: "ALL", label: "Tất cả" },
];

export const promotionAudienceOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả" },
  { value: "CUSTOMER", label: "Khách hàng" },
  { value: "DRIVER", label: "Tài xế" },
  { value: "MERCHANT", label: "Cửa hàng" },
  { value: "STAFF", label: "Nhân viên" },
];

export const promotionChannelOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả dịch vụ" },
  { value: "RIDE", label: "Xe 2 bánh (Ride)" },
  { value: "FOOD", label: "Giao đồ ăn (Food)" },
];

export const promotionServiceTypeOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả dịch vụ" },
  { value: "RIDE", label: "Xe 2 bánh (Ride)" },
  { value: "FOOD", label: "Giao đồ ăn (Food)" },
];

export const promotionStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "ACTIVE", label: "Đang hoạt động" },
  { value: "SCHEDULED", label: "Đã lên lịch" },
  { value: "PAUSED", label: "Tạm dừng" },
  { value: "ENDED", label: "Đã kết thúc" },
];

export const storeApprovalStatusOptions: SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả trạng thái" },
  { value: "PENDING", label: "Chờ duyệt" },
  { value: "IN_REVIEW", label: "Đang xét" },
  { value: "APPROVED", label: "Đã duyệt" },
  { value: "REJECTED", label: "Từ chối" },
];

export function optionsWithoutAll(
  options: readonly SearchSelectOption[],
): SearchSelectOption[] {
  return options.filter((option) => option.value !== "ALL");
}

/**
 * Live hook that fetches service regions directly from backend API (/api/ops/zones?status=ALL)
 * and produces dynamic search filter options.
 */
export function useLiveRegionFilterOptions(): {
  options: SearchSelectOption[];
  isPending: boolean;
} {
  const { data: zones = [], isPending } = useZonesQuery("ALL");
  const options = useMemo(() => {
    return [
      { value: "ALL", label: "Tất cả khu vực" },
      ...zones.map((z) => ({ value: z.code, label: z.label })),
    ];
  }, [zones]);
  return { options, isPending };
}

/**
 * Live hook that fetches store catalog categories directly from backend API (/api/ops/catalog/categories)
 * and produces dynamic search filter options.
 */
export function useLiveCatalogCategoryOptions(): {
  options: SearchSelectOption[];
  isPending: boolean;
} {
  const { data, isPending } = useCatalogCategoriesQuery({ page: 1, limit: 50 });
  const options = useMemo(() => {
    const items = data?.items ?? [];
    return [
      { value: "ALL", label: "Tất cả danh mục" },
      ...items.map((c) => ({
        value: c.code,
        label: c.displayName || c.name || c.code,
      })),
    ];
  }, [data]);
  return { options, isPending };
}
