/** Nest GET /v1/ops/settlements batch (envelope.data.items[]). */

export type NestSettlementEntityType = "RIDE" | "FOOD_ORDER";

export type NestSettlementBatch = {
  /** Vietnam business day (Asia/Ho_Chi_Minh) YYYY-MM-DD — COD journal grouping, not a payout batch. */
  day: string;
  journalCount: number;
  totalAmountVnd: number;
  entityTypes: NestSettlementEntityType[];
};

export type NestSettlementPage = {
  items: NestSettlementBatch[];
  page: number;
  limit: number;
  total: number;
};
