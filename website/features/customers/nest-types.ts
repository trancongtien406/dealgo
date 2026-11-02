export type NestOpsGrantStatus = "PENDING" | "ACTIVE" | "SUSPENDED";

export type NestOpsUserGrant = {
  id: string;
  role: string;
  status: NestOpsGrantStatus;
};

/** Nest `OpsUserListItem` for CUSTOMER role directory. */
export type NestOpsCustomer = {
  id: string;
  displayName: string;
  phone: string | null;
  phoneMasked?: string | null;
  email: string | null;
  phoneVerifiedAt: string | null;
  emailVerifiedAt: string | null;
  createdAt: string;
  grants: NestOpsUserGrant[];
  /** S027 (DEC-PROD-037): null/absent = active account. */
  deletion?: unknown;
  region?: string | null;
  area?: string | null;
  rides?: number;
  food?: number;
  delivery?: number;
  spend?: number;
};

export type NestOpsCustomerPage = {
  items: NestOpsCustomer[];
  page: number;
  limit: number;
  total: number;
};
