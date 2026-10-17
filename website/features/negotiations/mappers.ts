import type { StatusTone } from "@/lib/admin-format";
import type { NegotiationSessionStatus } from "@/features/negotiations/types";

const labels: Record<NegotiationSessionStatus, string> = {
  OPEN: "Đang mở",
  ACCEPTED: "Đã chốt",
  EXPIRED: "Hết hạn",
  LOCKED: "Tạm khóa",
};
const tones: Record<NegotiationSessionStatus, StatusTone> = {
  OPEN: "success",
  ACCEPTED: "delivery",
  EXPIRED: "food",
  LOCKED: "danger",
};

const offerKindLabels: Record<string, string> = {
  ACCEPT: "Đồng ý giá",
  COUNTER: "Trả giá",
};

const offerStatusLabels: Record<string, string> = {
  PENDING: "Đang chờ",
  SELECTED: "Đã chọn",
  LOST: "Không chọn",
};

export function negotiationSessionStatusLabel(
  status: NegotiationSessionStatus,
) {
  return labels[status];
}
export function negotiationSessionStatusTone(status: NegotiationSessionStatus) {
  return tones[status];
}

export function negotiationOfferKindLabel(kind: string) {
  return offerKindLabels[kind] ?? kind;
}

export function negotiationOfferStatusLabel(status: string) {
  return offerStatusLabels[status] ?? status;
}

export function negotiationOfferStatusTone(status: string): StatusTone {
  if (status === "SELECTED") return "success";
  if (status === "LOST") return "food";
  if (status === "PENDING") return "delivery";
  return "brand";
}
