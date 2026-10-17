import { isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(_request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!isUuid(id)) {
    return Response.json(
      { success: false, message: "Mã cửa hàng không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    path: `/v1/ops/stores/${id}`,
  });
  return jsonFromOpsUpstream(result);
}
