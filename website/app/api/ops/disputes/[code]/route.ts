import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = {
  params: Promise<{ code: string }>;
};

export async function GET(_request: Request, context: RouteContext) {
  const { code } = await context.params;
  const result = await fetchOpsUpstream({
    path: `/v1/ops/disputes/${encodeURIComponent(code)}`,
  });

  return jsonFromOpsUpstream(result);
}
