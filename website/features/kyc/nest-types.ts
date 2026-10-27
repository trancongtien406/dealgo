/** Nest PartnerApplicationView subset used by Admin BFF (envelope.data). */
export type NestPartnerStatus = "DRAFT" | "SUBMITTED" | "APPROVED" | "REJECTED";

export type NestPartnerRole = "DRIVER" | "MERCHANT";

export type NestPartnerApplicationView = {
  id: string;
  role: NestPartnerRole;
  status: NestPartnerStatus;
  metadata: Record<string, unknown>;
  /** Case detail only: applicant's account phone (ops can call). */
  applicantPhone?: string;
  documents: Array<{
    index?: number;
    kind?: string | null;
    label: string;
    contentType: string;
    sizeBytes: number;
    uploadedAt: string;
    /** False for seed/legacy refs without stored bytes. */
    hasFile?: boolean;
  }>;
  reason: string | null;
  /** Sections ops asked the applicant to fix (DEC-PROD-020). */
  issues?: Array<{ section: string; note: string }>;
  reviewedBy: string | null;
  reviewedAt: string | null;
  submittedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type NestPartnerApplicationList = {
  applications: NestPartnerApplicationView[];
  total?: number;
  page?: number;
  limit?: number;
};
