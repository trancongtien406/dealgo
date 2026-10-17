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
  const region = searchParams.get("region")?.trim() || undefined;
  const service = searchParams.get("service")?.trim() || undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/customers",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(status ? { status } : {}),
      ...(region ? { region } : {}),
      ...(service ? { service } : {}),
    },
  });
  return jsonFromOpsUpstream(result);
}
