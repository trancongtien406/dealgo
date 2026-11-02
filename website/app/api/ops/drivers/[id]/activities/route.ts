import { isUuid } from "@/lib/api/ops-bff-guards";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!isUuid(id)) {
    return Response.json(
      { success: false, message: "Mã tài xế không hợp lệ." },
      { status: 400 },
    );
  }

  const { searchParams } = new URL(request.url);
  const tab = searchParams.get("tab")?.trim() || undefined;
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);

  const result = await fetchOpsUpstream({
    path: `/v1/ops/drivers/${id}/activities`,
    searchParams: {
      ...(tab ? { tab } : {}),
      page,
      limit,
    },
  });
  return jsonFromOpsUpstream(result);
}

