export type FaqStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";
export type FaqCategory = "POLICY" | "OPS" | "PRODUCT" | "TECH";

export type FaqRow = {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: FaqStatus;
  category: FaqCategory;
  sortOrder: number;
  updatedAt: string;
};
