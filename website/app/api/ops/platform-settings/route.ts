import type { NextRequest } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const qs = searchParams.toString();
  const result = await fetchOpsUpstream({
    path: qs ? `/v1/ops/platform-settings?${qs}` : "/v1/ops/platform-settings",
  });
  return jsonFromOpsUpstream(result);
}
