import { enrichOpsRidePayload } from "@/lib/api/ops-people";
import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { readInterveneReasonBody } from "@/lib/api/ops-intervene-body";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã chuyến không hợp lệ." },
      { status: 400 },
    );
  }

  const body = await readInterveneReasonBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/rides/${id}/cancel`,
    body: { reason: body.reason },
  });
  if (result.ok) {
    return jsonFromOpsUpstream({
      ...result,
      data: await enrichOpsRidePayload(result.data),
    });
  }
  return jsonFromOpsUpstream(result);
}
