import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { opsDateRangeFromSearch } from "@/lib/api/ops-date-range";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);

  const upstreamParams: Record<string, string | number> = { page, limit };
  const q = searchParams.get("q");
  const status = searchParams.get("status");
  const service = searchParams.get("service");
  const payment = searchParams.get("payment");

  if (q) upstreamParams.q = q;
  if (status) upstreamParams.status = status;
  if (service) upstreamParams.service = service;
  if (payment) upstreamParams.payment = payment;
  Object.assign(upstreamParams, opsDateRangeFromSearch(searchParams));

  const result = await fetchOpsUpstream({
    path: "/v1/ops/transactions",
    searchParams: upstreamParams,
  });
  return jsonFromOpsUpstream(result);
}
