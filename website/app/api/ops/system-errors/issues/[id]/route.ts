import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(_request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!/^\d{1,20}$/.test(id)) {
    return Response.json(
      { success: false, message: "Mã lỗi không hợp lệ." },
      { status: 400 },
    );
  }
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({ path: `/v1/ops/system-errors/issues/${id}` }),
  );
}
