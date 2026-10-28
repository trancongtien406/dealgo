import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Only the filters Nest understands are forwarded; it validates each one. */
const FORWARDED = [
  "project",
  "environment",
  "status",
  "period",
  "sort",
  "q",
  "cursor",
] as const;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const searchParams: Record<string, string> = {};
  for (const key of FORWARDED) {
    const value = url.searchParams.get(key)?.trim();
    if (value) searchParams[key] = value;
  }
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({
      path: "/v1/ops/system-errors/issues",
      searchParams,
    }),
  );
}
