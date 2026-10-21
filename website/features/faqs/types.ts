export type FaqStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";
export type FaqCategory = "POLICY" | "OPS" | "PRODUCT" | "TECH";
/** INTERNAL = staff playbook; others = in-app help for that role (DEC-PROD-021). */
export type FaqAudience = "INTERNAL" | "CUSTOMER" | "DRIVER" | "MERCHANT";

export type FaqRow = {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: FaqStatus;
  category: FaqCategory;
  audience: FaqAudience;
  sortOrder: number;
  updatedAt: string;
};
