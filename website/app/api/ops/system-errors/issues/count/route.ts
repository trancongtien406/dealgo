import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET() {
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({ path: "/v1/ops/system-errors/issues/count" }),
  );
}
