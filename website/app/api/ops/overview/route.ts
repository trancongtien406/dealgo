import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

/** Proxies Nest GET /v1/ops/overview when BE-OPS-KPI is available. */
export async function GET() {
  const result = await fetchOpsUpstream({
    path: "/v1/ops/overview",
  });
  return jsonFromOpsUpstream(result);
}
