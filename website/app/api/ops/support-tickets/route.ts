import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const FORWARDED = ["status", "category", "channel", "q", "page", "limit"] as const;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const searchParams: Record<string, string> = {};
  for (const key of FORWARDED) {
    const value = url.searchParams.get(key)?.trim();
    if (value) {
      searchParams[key] = value;
    }
  }
  const result = await fetchOpsUpstream({ path: "/v1/ops/support-tickets", searchParams });
  return jsonFromOpsUpstream(result);
}
