import type {
  TransactionListItem,
  TxStatus,
} from "@/features/transactions/types";
import { apiFetch } from "@/lib/api/client";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";
import { setOpsDateRange, type OpsDateRange } from "@/lib/api/ops-date-range";

export type FetchTransactionsParams = ListQuery &
  OpsDateRange & {
  status?: TxStatus | "ALL";
  service?: string | null;
  payment?: string | null;
};

export async function fetchTransactions(
  params: FetchTransactionsParams,
): Promise<PaginatedList<TransactionListItem>> {
  const search = new URLSearchParams();
  search.set("page", String(Math.max(1, params.page)));
  search.set("limit", String(Math.max(1, Math.min(50, params.limit))));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  if (params.service && params.service !== "ALL")
    search.set("service", params.service);
  if (params.payment && params.payment !== "ALL")
    search.set("payment", params.payment);
  setOpsDateRange(search, params);

  const envelope = await apiFetch<{
    success: boolean;
    data: {
      items: TransactionListItem[];
      total: number;
      page: number;
      limit: number;
    };
  }>(`${apiPaths.opsTransactions()}?${search.toString()}`);

  return {
    items: envelope.data.items,
    total: envelope.data.total,
    page: envelope.data.page,
    limit: envelope.data.limit,
  };
}
