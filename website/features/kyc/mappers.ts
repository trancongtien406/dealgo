import type { StatusTone } from "@/lib/admin-format";
import type {
  NestPartnerApplicationView,
  NestPartnerStatus,
} from "@/features/kyc/nest-types";
import type { KycCase, KycStatus } from "@/features/kyc/types";
import { formatOpsDate } from "@/lib/ops-time";
import {
  businessTypeLabel,
  maskAccountNumber,
  mapPartnerDocuments,
  mapPartnerIssues,
  registrationSubjectLabel,
} from "@/features/kyc/partner-review";
import { readKycReviewChecks } from "@/features/kyc/review-checks";
import { autoApproveSkipLabels, readOcrFields } from "@/features/kyc/ocr-fields";

const nestPartnerStatusMap: Record<NestPartnerStatus, KycStatus> = {
  DRAFT: "UNDER_REVIEW",
  SUBMITTED: "UNDER_REVIEW",
  IN_REVIEW: "IN_REVIEW",
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
  if (status === "IN_REVIEW") {
    return "IN_REVIEW";
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
  const meta = app.metadata;
  const services = [
    meta.rideService === true ? "Chở khách" : null,
    meta.foodService === true ? "Giao đồ ăn" : null,
  ].filter(Boolean);
  const account = readString(meta, "bankAccountNumber");
  const details: Array<[string, string]> = (
    [
      ["Họ và tên", readString(meta, "fullName")],
      ["Ngày sinh", readString(meta, "birthDate")],
      ["Địa chỉ", readString(meta, "address")],
      ["Số CCCD", readString(meta, "idNumber")],
      ["Dịch vụ", services.join(", ")],
      ["Hạng GPLX", readString(meta, "licenseClass")],
      ["Số GPLX", readString(meta, "licenseNumber")],
      ["Hãng xe", readString(meta, "vehicleBrand")],
      ["Dòng xe", readString(meta, "vehicleModel")],
      ["Năm sản xuất", readString(meta, "vehicleYear")],
      ["Tên cửa hàng", readString(meta, "shopName")],
      ["Địa chỉ cửa hàng", readString(meta, "shopAddress")],
      ["Loại hình", businessTypeLabel(readString(meta, "businessType"))],
      [
        "Hình thức đăng ký",
        registrationSubjectLabel(readString(meta, "registrationSubject")),
      ],
      ["Người đại diện", readString(meta, "representativeName")],
      ["Ngân hàng", readString(meta, "bankName")],
      ["Số tài khoản", account ? maskAccountNumber(account) : ""],
      ["Chủ tài khoản", readString(meta, "bankAccountHolder")],
    ] as Array<[string, string]>
  ).filter(([, value]) => value.length > 0);
  return {
    code: app.id,
    userId: app.userId,
    role: app.role,
    initials,
    name,
    submittedAt: formatOpsDate(app.submittedAt ?? app.createdAt),

    phoneMasked:
      app.applicantPhone ||
      readString(app.metadata, "phoneMasked") ||
      readString(app.metadata, "phone") ||
      "—",
    phone: app.applicantPhone || undefined,
    email: app.applicantEmail || readString(app.metadata, "email") || undefined,
    area:
      readString(app.metadata, "area") ||
      readString(app.metadata, "address") ||
      readString(app.metadata, "shopAddress") ||
      readString(app.metadata, "serviceRegionCode") ||
      "—",
    vehicleKind:
      app.role === "DRIVER"
        ? readString(app.metadata, "vehicleType") ||
          readString(app.metadata, "vehicleKind") ||
          "Tài xế"
        : "Cửa hàng",
    vehicle:
      [
        readString(app.metadata, "vehicleBrand"),
        readString(app.metadata, "vehicleModel"),
      ]
        .filter(Boolean)
        .join(" ") ||
      readString(app.metadata, "vehicle") ||
      readString(app.metadata, "shopName") ||
      "—",
    plate:
      readString(app.metadata, "vehiclePlate") ||
      readString(app.metadata, "plate") ||
      "—",
    status: nestPartnerStatusToFeature(app.status),
    activity:
      app.role === "DRIVER"
        ? app.status === "APPROVED"
          ? "Tài xế · Đã duyệt"
          : "Tài xế · Chờ xử lý"
        : app.status === "APPROVED"
          ? "Merchant · Đã duyệt"
          : "Merchant · Chờ xử lý",
    vehicleClassCode:
      app.role === "DRIVER"
        ? readString(app.metadata, "vehicleClassCode") || null
        : null,
    licenseClass: readString(app.metadata, "licenseClass") || null,
    documentsWaived: app.metadata?.documentsWaived === true,
    activated: app.status === "APPROVED",
    details,
    documents: mapPartnerDocuments(app),
    reason: app.reason,
    issues: mapPartnerIssues(app),
    reviewedAt: app.reviewedAt ? formatOpsDate(app.reviewedAt) : null,
    checks: readKycReviewChecks(app.metadata ?? {}),
    ocrFields: readOcrFields(app.metadata ?? {}),
    autoApproved: app.metadata?.autoApproved === true,
    autoApproveSkipped: autoApproveSkipLabels(app.metadata?.autoApproveSkipped),
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
  IN_REVIEW: "Đang được duyệt",
  NEEDS_MORE_INFO: "Chờ bổ sung",
  APPROVED: "Đã duyệt",
  REJECTED: "Từ chối",
  PRIORITY: "Ưu tiên",
};
const tones: Record<KycStatus, StatusTone> = {
  UNDER_REVIEW: "delivery",
  IN_REVIEW: "brand",
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
  { value: "IN_REVIEW" as const, label: labels.IN_REVIEW },
  { value: "NEEDS_MORE_INFO" as const, label: labels.NEEDS_MORE_INFO },
  { value: "PRIORITY" as const, label: labels.PRIORITY },
  { value: "APPROVED" as const, label: labels.APPROVED },
  { value: "REJECTED" as const, label: labels.REJECTED },
];
