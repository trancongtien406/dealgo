/** Nest GET /v1/ops/exceptions item (envelope.data). */
export type NestExceptionReason = "stuck" | "terminal";

export type NestExceptionKind = "ride" | "food";

export type NestExceptionItem = {
  kind: NestExceptionKind;
  id: string;
  status: string;
  reason: NestExceptionReason;
  updatedAt: string;
};

export type NestExceptionPage = {
  items: NestExceptionItem[];
  page: number;
  limit: number;
  total: number;
};
