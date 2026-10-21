import type {
  FaqAudience,
  FaqCategory,
  FaqRow,
  FaqStatus,
} from "@/features/faqs/types";

const AUDIENCES: readonly FaqAudience[] = [
  "INTERNAL",
  "CUSTOMER",
  "DRIVER",
  "MERCHANT",
];

export function mapNestFaq(raw: {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: string;
  category: string;
  audience?: string;
  sortOrder: number;
  updatedAt: string;
}): FaqRow {
  return {
    id: raw.id,
    openId: raw.openId,
    question: raw.question,
    suggestedAnswer: raw.suggestedAnswer,
    status: raw.status as FaqStatus,
    category: raw.category as FaqCategory,
    audience: AUDIENCES.includes(raw.audience as FaqAudience)
      ? (raw.audience as FaqAudience)
      : "INTERNAL",
    sortOrder: raw.sortOrder,
    updatedAt: raw.updatedAt,
  };
}

export function faqStatusLabel(status: FaqStatus): string {
  switch (status) {
    case "DRAFT":
      return "Nháp PROPOSED";
    case "PUBLISHED":
      return "Đã xuất bản";
    case "ARCHIVED":
      return "Lưu trữ";
  }
}

export function faqCategoryLabel(category: FaqCategory): string {
  switch (category) {
    case "POLICY":
      return "Chính sách";
    case "OPS":
      return "Vận hành";
    case "PRODUCT":
      return "Sản phẩm";
    case "TECH":
      return "Kỹ thuật";
  }
}

export const FAQ_AUDIENCE_OPTIONS: ReadonlyArray<{
  value: FaqAudience;
  label: string;
}> = [
  { value: "INTERNAL", label: "Nội bộ (nhân viên)" },
  { value: "CUSTOMER", label: "Khách hàng (app)" },
  { value: "DRIVER", label: "Tài xế (app)" },
  { value: "MERCHANT", label: "Cửa hàng (app)" },
];

export function faqAudienceLabel(audience: FaqAudience): string {
  return (
    FAQ_AUDIENCE_OPTIONS.find((o) => o.value === audience)?.label ?? audience
  );
}
