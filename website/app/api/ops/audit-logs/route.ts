import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const q = url.searchParams.get("q") ?? undefined;
  const entityType = url.searchParams.get("entityType") ?? undefined;
  const result = url.searchParams.get("result") ?? undefined;
  const page = url.searchParams.get("page") ?? undefined;
  const limit = url.searchParams.get("limit") ?? undefined;

  const res = await fetchOpsUpstream({
    path: "/v1/ops/audit-logs",
    searchParams: {
      ...(q ? { q } : {}),
      ...(entityType ? { entityType } : {}),
      ...(result ? { result } : {}),
      ...(page ? { page } : {}),
      ...(limit ? { limit } : {}),
    },
  });

  return jsonFromOpsUpstream(res);
}
