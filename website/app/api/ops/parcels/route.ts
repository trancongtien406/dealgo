import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { isParcelOutcomeFilter } from "@/features/parcels/mappers";

/** DEC-PROD-071: ops parcel list (rides.read upstream). */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);
  const outcome = searchParams.get("outcome");
  const q = searchParams.get("q")?.trim();
  const upstreamParams: Record<string, string | number | undefined> = { page, limit };
  if (outcome && outcome !== "ALL" && isParcelOutcomeFilter(outcome)) {
    upstreamParams.outcome = outcome;
  }
  if (q) upstreamParams.q = q.slice(0, 80);
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({ path: "/v1/ops/parcels", searchParams: upstreamParams }),
  );
}
