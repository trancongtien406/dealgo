import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** DEC-PROD-055: list public pages (Nest checks content.write). */
export async function GET() {
  const result = await fetchOpsUpstream({ method: "GET", path: "/v1/ops/public-pages" });
  return jsonFromOpsUpstream(result);
}
