import { forwardOpsJsonMutation } from "@/lib/api/ops-forward-json";

type RouteContext = { params: Promise<{ id: string }> };

export async function PUT(request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!/^\d{1,20}$/.test(id)) {
    return Response.json(
      { success: false, message: "Mã lỗi không hợp lệ." },
      { status: 400 },
    );
  }
  return forwardOpsJsonMutation(
    request,
    "PUT",
    `/v1/ops/system-errors/issues/${id}/status`,
  );
}
