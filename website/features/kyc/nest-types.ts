/** Nest PartnerApplicationView subset used by Admin BFF (envelope.data). */
export type NestPartnerStatus = "DRAFT" | "SUBMITTED" | "APPROVED" | "REJECTED";

export type NestPartnerRole = "DRIVER" | "MERCHANT";

export type NestPartnerApplicationView = {
  id: string;
  role: NestPartnerRole;
  status: NestPartnerStatus;
  metadata: Record<string, unknown>;
  documents: Array<{
    key: string;
    label: string;
    contentType: string;
    sizeBytes: number;
    uploadedAt: string;
  }>;
  reason: string | null;
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
