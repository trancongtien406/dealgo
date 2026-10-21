import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

/** DEC-PROD-036: signed-in operator id + superAdmin flag. */
export async function GET() {
  const result = await fetchOpsUpstream({ path: "/v1/ops/staff/me" });
  return jsonFromOpsUpstream(result);
}
