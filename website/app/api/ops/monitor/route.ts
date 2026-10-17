import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

/** Proxies Nest GET /v1/ops/monitor/snapshot (BE-OPS-KPI). */
export async function GET() {
  const result = await fetchOpsUpstream({
    path: "/v1/ops/monitor/snapshot",
  });
  return jsonFromOpsUpstream(result);
}
