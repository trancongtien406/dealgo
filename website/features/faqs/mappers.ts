import type { FaqCategory, FaqRow, FaqStatus } from "@/features/faqs/types";

export function mapNestFaq(raw: {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: string;
  category: string;
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
    sortOrder: raw.sortOrder,
    updatedAt: raw.updatedAt,
  };
}

export function faqStatusLabel(status: FaqStatus): string {
  switch (status) {
    case "DRAFT":
      return "Nháp PROPOSED";
    case "PUBLISHED":
      return "Đã xuất bản (nội bộ)";
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
