import type { StatusTone } from "@/lib/admin-format";
import type { CatalogStatus } from "@/features/catalog/types";

const labels: Record<CatalogStatus, string> = {
  ACTIVE: "Đang hiển thị",
  HIDDEN: "Đang ẩn",
};

const tones: Record<CatalogStatus, StatusTone> = {
  ACTIVE: "success",
  HIDDEN: "danger",
};

export function catalogStatusLabel(status: CatalogStatus) {
  return labels[status] ?? status;
}

export function catalogStatusTone(status: CatalogStatus): StatusTone {
  return tones[status] ?? "brand";
}
