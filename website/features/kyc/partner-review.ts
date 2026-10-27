import type {
  NestPartnerApplicationView,
  NestPartnerRole,
} from "@/features/kyc/nest-types";
import { formatOpsDate } from "@/lib/ops-time";

/** Vietnamese labels for document kinds (backend PARTNER_DOCUMENT_KINDS). */
export const PARTNER_DOCUMENT_LABELS: Record<string, string> = {
  ID_FRONT: "CCCD — mặt trước",
  ID_BACK: "CCCD — mặt sau",
  SELFIE: "Ảnh chân dung",
  LICENSE: "Giấy phép lái xe",
  VEHICLE_REG: "Đăng ký xe",
  BUSINESS_LICENSE: "Giấy phép kinh doanh",
  REP_ID_FRONT: "CCCD người đại diện — mặt trước",
  REP_ID_BACK: "CCCD người đại diện — mặt sau",
  STOREFRONT: "Ảnh mặt tiền cửa hàng",
};

/** Sections ops can ask the applicant to fix (backend PARTNER_ISSUE_SECTIONS). */
export const PARTNER_ISSUE_SECTIONS: Record<
  NestPartnerRole,
  ReadonlyArray<{ value: string; label: string }>
> = {
  DRIVER: [
    { value: "PERSONAL", label: "Thông tin cá nhân" },
    { value: "ID_CARD", label: "Ảnh CCCD" },
    { value: "SELFIE", label: "Ảnh chân dung" },
    { value: "LICENSE", label: "Giấy phép lái xe" },
    { value: "VEHICLE", label: "Phương tiện / đăng ký xe" },
    { value: "BANK", label: "Tài khoản nhận tiền" },
    { value: "OTHER", label: "Khác" },
  ],
  MERCHANT: [
    { value: "SHOP_INFO", label: "Thông tin cửa hàng" },
    { value: "REPRESENTATIVE", label: "Người đại diện" },
    { value: "BUSINESS_DOCS", label: "Giấy tờ kinh doanh" },
    { value: "STOREFRONT", label: "Ảnh mặt tiền" },
    { value: "BANK", label: "Tài khoản nhận tiền" },
    { value: "OTHER", label: "Khác" },
  ],
};

export type PartnerDocument = {
  index: number;
  kind: string | null;
  label: string;
  contentType: string;
  sizeLabel: string;
  uploadedAt: string;
  hasFile: boolean;
  isImage: boolean;
  /** Same-origin BFF URL; null when the ref has no stored bytes. */
  url: string | null;
};

export type PartnerIssue = { section: string; note: string };

export function issueSectionLabel(role: NestPartnerRole, section: string): string {
  return (
    PARTNER_ISSUE_SECTIONS[role].find((row) => row.value === section)?.label ??
    section
  );
}

export function mapPartnerDocuments(
  app: Pick<NestPartnerApplicationView, "id" | "documents">,
): PartnerDocument[] {
  return (app.documents ?? []).map((doc, position) => {
    const index = typeof doc.index === "number" ? doc.index : position;
    const hasFile = doc.hasFile !== false;
    return {
      index,
      kind: doc.kind ?? null,
      label:
        (doc.kind && PARTNER_DOCUMENT_LABELS[doc.kind]) || doc.label || "Giấy tờ",
      contentType: doc.contentType,
      sizeLabel: formatBytes(doc.sizeBytes),
      uploadedAt: formatOpsDate(doc.uploadedAt),
      hasFile,
      isImage: doc.contentType.startsWith("image/"),
      url: hasFile
        ? `/api/ops/partner-applications/${app.id}/documents/${index}`
        : null,
    };
  });
}

export function mapPartnerIssues(app: NestPartnerApplicationView): PartnerIssue[] {
  return Array.isArray(app.issues)
    ? app.issues.filter(
        (issue): issue is PartnerIssue =>
          typeof issue?.section === "string" && typeof issue?.note === "string",
      )
    : [];
}

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return "—";
  }
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${Math.round(bytes / 1024)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1).replace(".", ",")} MB`;
}

/** Shows only the last 4 digits of a bank account number. */
export function maskAccountNumber(raw: string): string {
  const digits = raw.replace(/\s+/g, "");
  if (digits.length <= 4) {
    return digits;
  }
  return `•••• ${digits.slice(-4)}`;
}

/** Validates an issue list before it is sent; returns a Vietnamese error or null. */
export function validateIssues(issues: PartnerIssue[]): string | null {
  if (issues.length === 0) {
    return "Chọn ít nhất một mục cần bổ sung.";
  }
  if (issues.some((issue) => issue.note.trim().length === 0)) {
    return "Mỗi mục cần bổ sung phải có ghi chú cho đối tác.";
  }
  if (issues.some((issue) => issue.note.trim().length > 300)) {
    return "Ghi chú mỗi mục tối đa 300 ký tự.";
  }
  return null;
}

const BUSINESS_TYPE_LABELS: Record<string, string> = {
  FOOD_RESTAURANT: "Quán ăn / Nhà hàng",
  CAFE_TEA: "Quán cà phê / Trà sữa",
  GROCERY: "Siêu thị / Cửa hàng thực phẩm",
  CONVENIENCE: "Cửa hàng tiện lợi",
  OTHER: "Loại hình khác",
};

const REGISTRATION_SUBJECT_LABELS: Record<string, string> = {
  HOUSEHOLD: "Hộ kinh doanh",
  COMPANY: "Doanh nghiệp",
  OTHER: "Khác",
};

/** KYB metadata stores codes; older rows may still hold Vietnamese text. */
export function businessTypeLabel(raw: string): string {
  return BUSINESS_TYPE_LABELS[raw] ?? raw;
}

export function registrationSubjectLabel(raw: string): string {
  return REGISTRATION_SUBJECT_LABELS[raw] ?? raw;
}
