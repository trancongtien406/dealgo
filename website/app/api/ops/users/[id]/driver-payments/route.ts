import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkOpsReason, opsAccountActionErrorMessage } from "@/lib/api/ops-reason-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { checkDriverPayment } from "@/lib/driver-balance";

type RouteContext = { params: Promise<{ id: string }> };

/** Ops records a partial driver payment / top-up or a DealGo payout (audited). */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã người dùng không hợp lệ." },
      { status: 400 },
    );
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Yêu cầu không hợp lệ." }, { status: 400 });
  }
  const body = (typeof json === "object" && json !== null ? json : {}) as Record<string, unknown>;
  const reason = checkOpsReason(body);
  if (!reason.ok) {
    return NextResponse.json({ success: false, message: reason.message }, { status: 400 });
  }
  const payment = checkDriverPayment(body);
  if (!payment.ok) {
    return NextResponse.json({ success: false, message: payment.message }, { status: 400 });
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/users/${id}/driver-payments`,
    body: { ...payment.value, reason: reason.value.reason },
  });
  if (!result.ok) {
    const message = opsAccountActionErrorMessage(result.errorCode);
    return jsonFromOpsUpstream(message ? { ...result, message } : result);
  }
  return jsonFromOpsUpstream(result);
}
