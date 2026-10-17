/** Nest GET /v1/ops/settlements batch (envelope.data.items[]). */

export type NestSettlementEntityType = "RIDE" | "FOOD_ORDER";

export type NestSettlementBatch = {
  /** UTC calendar day YYYY-MM-DD — sandbox grouping, not a payout batch. */
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
