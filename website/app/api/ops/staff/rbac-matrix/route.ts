import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

/** DEC-PROD-045: the role → permission matrix comes from Nest (single source of truth). */
export async function GET() {
  const result = await fetchOpsUpstream({ path: "/v1/ops/staff/rbac-matrix" });
  return jsonFromOpsUpstream(result);
}
