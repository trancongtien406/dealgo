import { enrichOpsRidePayload } from "@/lib/api/ops-people";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);
  const status = searchParams.get("status") || undefined;
  const q = searchParams.get("q") || undefined;

  const zone = searchParams.get("zone") || undefined;

  const upstreamParams: Record<string, string | number | undefined> = {
    page,
    limit,
  };
  if (status && status !== "ALL") {
    upstreamParams.status = status;
  }
  if (q && q.trim()) {
    upstreamParams.q = q.trim();
  }
  if (zone && zone !== "ALL") {
    upstreamParams.zone = zone;
  }

  const result = await fetchOpsUpstream({
    path: "/v1/ops/rides",
    searchParams: upstreamParams,
  });
  if (result.ok) {
    return jsonFromOpsUpstream({
      ...result,
      data: await enrichOpsRidePayload(result.data),
    });
  }
  return jsonFromOpsUpstream(result);
}
