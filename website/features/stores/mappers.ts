import { personInitials, type StatusTone } from "@/lib/admin-format";
import { areaLabelFromRegionOrCoords } from "@/lib/service-region-labels";
import type { NestOpsStore, NestOpsStoreDetail } from "@/features/stores/nest-types";
import type {
  StoreKybStatus,
  StoreListItem,
  StoreSaleStatus,
} from "@/features/stores/types";

const saleLabels: Record<StoreSaleStatus, string> = {
  ACTIVE: "Đang mở",
  OPEN: "Đang mở",
  CLOSED: "Ngoài giờ mở cửa",
  PAUSED: "Tạm ngưng nhận đơn",
  BUSY: "Bếp đang bận",
  PENDING_APPROVAL: "Chờ duyệt",
  SUSPENDED: "Tạm khóa",
};
const saleTones: Record<StoreSaleStatus, StatusTone> = {
  ACTIVE: "success",
  OPEN: "success",
  CLOSED: "food",
  PAUSED: "danger",
  BUSY: "food",
  PENDING_APPROVAL: "food",
  SUSPENDED: "danger",
};

const kybLabels: Record<StoreKybStatus, string> = {
  APPROVED: "Đã duyệt",
  PENDING: "Chờ duyệt",
  PENDING_KYB: "Chờ KYB",
  REJECTED: "Từ chối",
  NEEDS_VERIFY: "Cần xác minh",
};
const kybTones: Record<StoreKybStatus, StatusTone> = {
  APPROVED: "success",
  PENDING: "food",
  PENDING_KYB: "food",
  REJECTED: "danger",
  NEEDS_VERIFY: "danger",
};

export function storeSaleStatusLabel(status: StoreSaleStatus) {
  return saleLabels[status];
}
export function storeSaleStatusTone(status: StoreSaleStatus) {
  return saleTones[status];
}
export function storeKybStatusLabel(status: StoreKybStatus) {
  return kybLabels[status];
}
export function storeKybStatusTone(status: StoreKybStatus) {
  return kybTones[status];
}

export function mapNestStoreToListItem(store: NestOpsStore): StoreListItem {
  const name = store.name.trim() || "Cửa hàng";
  return {
    code: store.id,
    initials: personInitials(name) || "CH",
    name,
    category: store.category?.trim() || "—",
    owner: shortId(store.ownerId),
    area: areaLabelFromRegionOrCoords({
      serviceRegionCode: store.serviceRegionCode,
      lat: store.lat,
      lng: store.lng,
    }),
    orders: store.itemCount,
    rating: null,
    sale: storeSaleFromNest(store),
    kyb: mapKybStatus(store.kyb),
    serviceModeUntil: store.serviceModeUntil ?? null,
    acceptSummary: storeAcceptSummary(store),
    prepMinutes: store.estimatedPrepMinutes ?? null,
    locationMissing: store.lat == null || store.lng == null,
    address: store.address || store.addressLabel || undefined,
    phone: store.ownerPhone || undefined,
    email: store.ownerEmail || undefined,
    ownerName: store.ownerName || undefined,
  };
}

export function mapNestStoreDetailToItem(store: NestOpsStoreDetail): StoreListItem {
  const base = mapNestStoreToListItem(store);
  return {
    ...base,
    rating: store.stats?.ratingAverage ?? null,
    orders: store.stats?.completedOrders ?? store.itemCount,
    items: store.items,
    kybDetail: store.kybDetail,
    stats: store.stats,
    recentOrders: store.recentOrders,
    recentReviews: store.recentReviews,
  };
}

/** "Thủ công" / "Tự động", plus the kitchen cap when one is set. */
export function storeAcceptSummary(
  store: Pick<NestOpsStore, "acceptSettings">,
): string | null {
  const settings = store.acceptSettings;
  if (!settings) return null;
  const mode = settings.acceptMode === "AUTO" ? "Tự động" : "Thủ công";
  return settings.maxActiveOrders != null
    ? `${mode} · tối đa ${settings.maxActiveOrders} đơn đang xử lý`
    : `${mode} · không giới hạn đơn`;
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

/** Live intake state from the backend (DEC-PROD-026/027); falls back to the legacy `sale` field. */
export function storeSaleFromNest(store: NestOpsStore): StoreSaleStatus | null {
  if (store.closedReason === "PAUSED" || store.serviceMode === "PAUSED")
    return "PAUSED";
  if (store.openNow === false) return "CLOSED";
  if (store.serviceMode === "BUSY") return "BUSY";
  if (store.openNow === true) return "OPEN";
  return mapSaleStatus(store.sale);
}

function mapSaleStatus(raw: string | null | undefined): StoreSaleStatus | null {
  if (!raw) return null;
  const key = raw.trim().toUpperCase();
  if (key === "OPEN" || key === "ACTIVE") return "OPEN";
  if (key === "CLOSED" || key === "PAUSED") return "CLOSED";
  if (key === "SUSPENDED") return "SUSPENDED";
  if (key === "PENDING_APPROVAL") return "PENDING_APPROVAL";
  return null;
}

function mapKybStatus(raw: string | null | undefined): StoreKybStatus | null {
  if (!raw) return null;
  const key = raw.trim().toUpperCase();
  if (key === "APPROVED") return "APPROVED";
  if (key === "REJECTED") return "REJECTED";
  if (
    key === "PENDING" ||
    key === "PENDING_KYB" ||
    key === "NEED_MORE" ||
    key === "NEEDS_VERIFY"
  ) {
    return "PENDING";
  }
  return null;
}
