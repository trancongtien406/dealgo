import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

export async function GET() {
  const result = await fetchOpsUpstream({ path: "/v1/ops/ride-zone-tariffs" });
  return jsonFromOpsUpstream(result);
}
