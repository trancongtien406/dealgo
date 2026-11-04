import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Platform-wide prepaid credit health for the ops board (DEC-PROD-093). */
export async function GET() {
  const result = await fetchOpsUpstream({
    path: "/v1/ops/driver-credit/summary",
  });
  return jsonFromOpsUpstream(result);
}
