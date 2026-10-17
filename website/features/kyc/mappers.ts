import type { StatusTone } from "@/lib/admin-format";
import type {
  NestPartnerApplicationView,
  NestPartnerStatus,
} from "@/features/kyc/nest-types";
import type { KycCase, KycStatus } from "@/features/kyc/types";
import { formatOpsDate } from "@/lib/ops-time";

const nestPartnerStatusMap: Record<NestPartnerStatus, KycStatus> = {
  DRAFT: "UNDER_REVIEW",
  SUBMITTED: "UNDER_REVIEW",
  APPROVED: "APPROVED",
  REJECTED: "REJECTED",
};

/** Feature filter → Nest partner-application status query (when applicable). */
export function kycFilterToNestPartnerStatus(
  status: KycStatus | "ALL",
): NestPartnerStatus | undefined {
  if (status === "ALL") {
    return undefined;
  }
  if (status === "APPROVED") {
    return "APPROVED";
  }
  if (status === "REJECTED") {
    return "REJECTED";
  }
  if (
    status === "UNDER_REVIEW" ||
    status === "PRIORITY" ||
    status === "NEEDS_MORE_INFO"
  ) {
    return "SUBMITTED";
  }
  return undefined;
}

export function nestPartnerStatusToFeature(
  status: NestPartnerStatus,
): KycStatus {
  return nestPartnerStatusMap[status];
}

export function mapNestPartnerApplicationToKycCase(
  app: NestPartnerApplicationView,
): KycCase {
  const name = readName(app.metadata) || shortId(app.id);
  const initials = initialsFrom(name);
  return {
    code: app.id,
    initials,
    name,
    submittedAt: formatOpsDate(app.submittedAt ?? app.createdAt),

    phoneMasked:
      readString(app.metadata, "phoneMasked") ||
      readString(app.metadata, "phone") ||
      "—",
    area: readString(app.metadata, "area") || "—",
    vehicleKind:
      app.role === "DRIVER"
        ? readString(app.metadata, "vehicleKind") || "Tài xế"
        : "Cửa hàng",
    vehicle:
      readString(app.metadata, "vehicle") ||
      readString(app.metadata, "shopName") ||
      "—",
    plate: readString(app.metadata, "plate") || "—",
    status: nestPartnerStatusToFeature(app.status),
    activity:
      app.role === "DRIVER"
        ? app.status === "APPROVED"
          ? "Tài xế · Đã duyệt"
          : "Tài xế · Chờ xử lý"
        : app.status === "APPROVED"
          ? "Merchant · Đã duyệt"
          : "Merchant · Chờ xử lý",
    activated: app.status === "APPROVED",
  };
}

function readName(metadata: Record<string, unknown>): string {
  return (
    readString(metadata, "fullName") ||
    readString(metadata, "shopName") ||
    readString(metadata, "name") ||
    ""
  );
}

function readString(metadata: Record<string, unknown>, key: string): string {
  const value = metadata[key];
  return typeof value === "string" ? value.trim() : "";
}

function initialsFrom(name: string): string {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    return "—";
  }
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return `${parts[0][0] ?? ""}${parts[parts.length - 1][0] ?? ""}`.toUpperCase();
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

const labels: Record<KycStatus, string> = {
  UNDER_REVIEW: "Đang xét duyệt",
  NEEDS_MORE_INFO: "Chờ bổ sung",
  APPROVED: "Đã duyệt",
  REJECTED: "Từ chối",
  PRIORITY: "Ưu tiên",
};
const tones: Record<KycStatus, StatusTone> = {
  UNDER_REVIEW: "delivery",
  NEEDS_MORE_INFO: "food",
  APPROVED: "success",
  REJECTED: "danger",
  PRIORITY: "brand",
};
export function kycStatusLabel(status: KycStatus) {
  return labels[status];
}
export function kycStatusTone(status: KycStatus) {
  return tones[status];
}
export const kycStatusFilterOptions = [
  { value: "ALL" as const, label: "Tất cả trạng thái" },
  { value: "UNDER_REVIEW" as const, label: labels.UNDER_REVIEW },
  { value: "NEEDS_MORE_INFO" as const, label: labels.NEEDS_MORE_INFO },
  { value: "PRIORITY" as const, label: labels.PRIORITY },
  { value: "APPROVED" as const, label: labels.APPROVED },
  { value: "REJECTED" as const, label: labels.REJECTED },
];
