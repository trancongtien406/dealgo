import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);
  const q = searchParams.get("q")?.trim();
  const status = searchParams.get("status")?.trim();

  const searchParamsOut: Record<string, string | number | undefined> = {
    page,
    limit,
  };
  if (q) searchParamsOut.q = q;
  if (status) searchParamsOut.status = status;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/exceptions",
    searchParams: searchParamsOut,
  });
  return jsonFromOpsUpstream(result);
}
