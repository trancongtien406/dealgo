import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const q = url.searchParams.get("q") ?? undefined;
  const status = url.searchParams.get("status") ?? undefined;
  const priority = url.searchParams.get("priority") ?? undefined;
  const type = url.searchParams.get("type") ?? undefined;
  const party = url.searchParams.get("party") ?? undefined;
  const page = url.searchParams.get("page") ?? undefined;
  const limit = url.searchParams.get("limit") ?? undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/disputes",
    searchParams: {
      ...(q ? { q } : {}),
      ...(status ? { status } : {}),
      ...(priority ? { priority } : {}),
      ...(type ? { type } : {}),
      ...(party ? { party } : {}),
      ...(page ? { page } : {}),
      ...(limit ? { limit } : {}),
    },
  });

  return jsonFromOpsUpstream(result);
}
