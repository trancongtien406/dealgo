import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const PASS_THROUGH = ["page", "limit", "storeId", "visibility", "maxStars", "q"] as const;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const searchParams: Record<string, string> = {};
  for (const key of PASS_THROUGH) {
    const value = url.searchParams.get(key)?.trim();
    if (value) searchParams[key] = value;
  }
  const result = await fetchOpsUpstream({ path: "/v1/ops/reviews", searchParams });
  return jsonFromOpsUpstream(result);
}
