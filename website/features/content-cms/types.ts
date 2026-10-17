import type { OpsIconName } from "@/components/ui/ops-icons";

export type ContentDocKey = "TERMS" | "PRIVACY";

export type LegalSection = {
  id: string;
  title: string;
  content: string;
  order: number;
};

export type LegalDocument = {
  key: ContentDocKey;
  title: string;
  badge: string;
  version: string;
  effectiveDate: string;
  summary: string;
  sections: LegalSection[];
  updatedAt: string;
  updatedBy: string;
};

export type SupportCategoryItem = {
  id: string;
  title: string;
  role: "CUSTOMER" | "DRIVER" | "MERCHANT";
  icon: OpsIconName;
  tone: string;
  items: string[];
};

export type SupportConfig = {
  systemStatusNotice: string;
  hotline: string;
  email: string;
  address: string;
  hours: string;
  categories: SupportCategoryItem[];
  updatedAt: string;
  updatedBy: string;
};
