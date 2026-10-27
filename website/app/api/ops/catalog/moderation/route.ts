import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { opsDateRangeFromSearch } from "@/lib/api/ops-date-range";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const q = url.searchParams.get("q") ?? undefined;
  const store = url.searchParams.get("store") ?? undefined;
  const category = url.searchParams.get("category") ?? undefined;
  const status = url.searchParams.get("status") ?? undefined;
  const page = url.searchParams.get("page") ?? undefined;
  const limit = url.searchParams.get("limit") ?? undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/catalog/moderation",
    searchParams: {
      ...(q ? { q } : {}),
      ...(store ? { store } : {}),
      ...(category ? { category } : {}),
      ...(status ? { status } : {}),
      ...(page ? { page } : {}),
      ...(limit ? { limit } : {}),
      ...opsDateRangeFromSearch(url.searchParams),
    },
  });

  return jsonFromOpsUpstream(result);
}
