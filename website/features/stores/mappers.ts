import { personInitials, type StatusTone } from "@/lib/admin-format";
import { areaLabelFromRegionOrCoords } from "@/lib/service-region-labels";
import type { NestOpsStore } from "@/features/stores/nest-types";
import type {
  StoreKybStatus,
  StoreListItem,
  StoreSaleStatus,
} from "@/features/stores/types";

const saleLabels: Record<StoreSaleStatus, string> = {
  ACTIVE: "Đang mở",
  OPEN: "Đang mở",
  CLOSED: "Tạm đóng",
  PAUSED: "Tạm đóng",
  PENDING_APPROVAL: "Chờ duyệt",
  SUSPENDED: "Tạm khóa",
};
const saleTones: Record<StoreSaleStatus, StatusTone> = {
  ACTIVE: "success",
  OPEN: "success",
  CLOSED: "food",
  PAUSED: "food",
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
    sale: mapSaleStatus(store.sale),
    kyb: mapKybStatus(store.kyb),
  };
}

function shortId(id: string): string {
  return id.slice(0, 8);
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
