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
  const sale = searchParams.get("sale")?.trim() || undefined;
  const region = searchParams.get("region")?.trim() || undefined;
  const category = searchParams.get("category")?.trim() || undefined;
  const kyb = searchParams.get("kyb")?.trim() || undefined;
  const location =
    searchParams.get("location")?.trim() === "MISSING" ? "MISSING" : undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/stores",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(status ? { status } : {}),
      ...(sale ? { sale } : {}),
      ...(region ? { region } : {}),
      ...(category ? { category } : {}),
      ...(kyb ? { kyb } : {}),
      ...(location ? { location } : {}),
    },
  });
  return jsonFromOpsUpstream(result);
}
