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

  const result = await fetchOpsUpstream({
    path: "/v1/ops/settlements",
    searchParams: { page, limit, ...opsDateRangeFromSearch(searchParams) },
  });
  return jsonFromOpsUpstream(result);
}
