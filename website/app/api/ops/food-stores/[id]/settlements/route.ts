import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkOpsReason } from "@/lib/api/ops-reason-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  checkStatementRange,
  merchantSettlementErrorMessage,
} from "@/lib/merchant-statement";

type RouteContext = { params: Promise<{ id: string }> };

/** (OPEN-018) Ops records that the store paid the commission for closed days. */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã cửa hàng không hợp lệ." },
      { status: 400 },
    );
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Yêu cầu không hợp lệ." },
      { status: 400 },
    );
  }
  const body = (
    typeof json === "object" && json !== null ? json : {}
  ) as Record<string, unknown>;
  const reason = checkOpsReason(body);
  if (!reason.ok) {
    return NextResponse.json(
      { success: false, message: reason.message },
      { status: 400 },
    );
  }
  const range = checkStatementRange(body, { closedOnly: true });
  if (!range.ok) {
    return NextResponse.json(
      { success: false, message: range.message },
      { status: 400 },
    );
  }
  const note =
    typeof body.note === "string" ? body.note.trim().slice(0, 500) : "";
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/food-stores/${id}/settlements`,
    body: {
      ...range.value,
      reason: reason.value.reason,
      ...(note ? { note } : {}),
    },
  });
  if (!result.ok) {
    const message = merchantSettlementErrorMessage(result.errorCode);
    return jsonFromOpsUpstream(message ? { ...result, message } : result);
  }
  return jsonFromOpsUpstream(result);
}
