import { enrichOpsDriverPayload } from "@/lib/api/ops-people";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);

  const q = searchParams.get("q")?.trim() || undefined;
  const status = searchParams.get("status")?.trim() || undefined;
  const service = searchParams.get("service")?.trim() || undefined;
  const region = searchParams.get("region")?.trim() || undefined;
  const activity = searchParams.get("activity")?.trim() || undefined;
  const kyc = searchParams.get("kyc")?.trim() || undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/drivers",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(status ? { status } : {}),
      ...(service ? { service } : {}),
      ...(region ? { region } : {}),
      ...(activity ? { activity } : {}),
      ...(kyc ? { kyc } : {}),
    },
  });
  if (result.ok) {
    return jsonFromOpsUpstream({
      ...result,
      data: await enrichOpsDriverPayload(result.data),
    });
  }
  return jsonFromOpsUpstream(result);
}
